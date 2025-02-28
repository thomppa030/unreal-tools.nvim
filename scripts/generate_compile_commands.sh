#!/bin/bash

ENGINE_PATH="$1"
PROJECT_DIR="$2"
PROJECT_NAME="$3"

function log() {
  echo "[unreal-tools] $1"
}

function error() {
  echo "[ERROR] $1" >&2
  exit 1
}

# Validate arguments
if [ -z "$ENGINE_PATH" ]; then
  error "Unreal Engine path not provided."
fi

if [ -z "$PROJECT_DIR" ]; then
  error "Project Directory not provided."
fi

if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(basename "$PROJECT_DIR")
  log "Project name not provided, using: $PROJECT_NAME"
fi

# Check if engine path exists
if [ ! -d "$ENGINE_PATH" ]; then
  error "Unreal Engine directory not found at: $ENGINE_PATH"
fi

# Build the path to the uproject file
UPROJECT_PATH="$PROJECT_DIR/$PROJECT_NAME.uproject"

# Check if the uproject file exists
if [ ! -f "$UPROJECT_PATH" ]; then
  log "Warning: $PROJECT_NAME.uproject not found at $UPROJECT_PATH"
  # Try to find any .uproject file
  UPROJECT_FILE=$(find "$PROJECT_DIR" -maxdepth 1 -name "*.uproject" | head -n 1)
  if [ -n "$UPROJECT_FILE" ]; then
    PROJECT_NAME=$(basename "$UPROJECT_FILE" .uproject)
    UPROJECT_PATH="$UPROJECT_FILE"
    log "Found Project file: $UPROJECT_PATH, using project name: $PROJECT_NAME"
  else
    error "No .uproject file found in $PROJECT_DIR"
  fi
fi

PLATFORM="Linux"
BUILD_SCRIPT="$ENGINE_PATH/Engine/Build/BatchFiles/Linux/Build.sh"

if [ ! -f "$BUILD_SCRIPT" ]; then
  error "Build script not found at $BUILD_SCRIPT"
fi

log "Generating compile commands.json for $PROJECT_NAME"
log "Engine Path: $ENGINE_PATH"
log "Project directory: $PROJECT_DIR"
log "Project file: $UPROJECT_PATH"

cd "$PROJECT_DIR" || error "Failed to change to project directory"

# Use the updated command format
CMD="$BUILD_SCRIPT -mode=GenerateClangDatabase -NoExecCodeGenActions -project=\"$UPROJECT_PATH\" -game -engine ${PROJECT_NAME}Editor $PLATFORM Development"
log "Running: $CMD"

# Run the build with output timestamps
eval "$CMD" 2>&1 | while read -r line; do
  echo "[$(date '+%H:%M:%S')] $line"
done

build_status=${PIPESTATUS[0]}
if [ $build_status -ne 0 ]; then
  error "Failed to generate compile_commands.json (exit code: $build_status)"
fi

# Check if generation was successful
if [ -f "$PROJECT_DIR/compile_commands.json" ]; then
  log "Success: compile_commands.json generated at $PROJECT_DIR/compile_commands.json"
else
  # Check other common locations
  if [ -f "$PROJECT_DIR/.vscode/compile_commands.json" ]; then
    log "Moving compile_commands.json from .vscode directory to project root"
    cp "$PROJECT_DIR/.vscode/compile_commands.json" "$PROJECT_DIR/compile_commands.json"
    log "Success: compile_commands.json copied to $PROJECT_DIR/compile_commands.json"
  elif [ -f "$ENGINE_PATH/compile_commands.json" ]; then
    log "Found compile_commands.json in engine directory, linking to project root"
    ln -sf "$ENGINE_PATH/compile_commands.json" "$PROJECT_DIR/compile_commands.json"
    log "Success: compile_commands.json linked to $PROJECT_DIR/compile_commands.json"
  else
    error "compile_commands.json not found after generation"
  fi
fi

exit 0
