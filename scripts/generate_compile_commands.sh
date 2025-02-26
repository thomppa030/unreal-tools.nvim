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

# Validate arguments - note the spaces after [ and before ]
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

# Check if engine path exists - fixed the variable here, it was using PROJECT_NAME
if [ ! -d "$ENGINE_PATH" ]; then
  error "Unreal Engine directory not found at: $ENGINE_PATH"
fi

# Check if we are in an UE Project
if [ ! -f "$PROJECT_DIR/$PROJECT_NAME.uproject" ]; then
  log "Warning: $PROJECT_NAME.uproject not found in $PROJECT_DIR"
  # Try to find any .uproject file
  UPROJECT_FILE=$(find "$PROJECT_DIR" -maxdepth 1 -name "*.uproject" | head -n 1)
  if [ -n "$UPROJECT_FILE" ]; then
    PROJECT_NAME=$(basename "$UPROJECT_FILE" .uproject)
    log "Found Project file: $UPROJECT_FILE, using project name: $PROJECT_NAME"
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

cd "$PROJECT_DIR" || error "Failed to change project directory"

log "Running: $BUILD_SCRIPT ${PROJECT_NAME}Editor $PLATFORM Development -Mode=GenerateClangDatabase"
"$BUILD_SCRIPT" "${PROJECT_NAME}Editor" "$PLATFORM" Development -Mode=GenerateClangDatabase

# Check if generation was successful
if [ $? -ne 0 ]; then
  error "Failed to generate compile_commands.json"
fi

# Move the compile_commands.json to project root if it's in a subdirectory
if [ -f "$PROJECT_DIR/.vscode/compile_commands.json" ] && [ ! -f "$PROJECT_DIR/compile_commands.json" ]; then
  log "Moving compile_commands.json to project root"
  cp "$PROJECT_DIR/.vscode/compile_commands.json" "$PROJECT_DIR/compile_commands.json"
fi

if [ -f "$PROJECT_DIR/compile_commands.json" ]; then
  log "Success: compile_commands.json generated at $PROJECT_DIR/compile_commands.json"
else
  error "compile_commands.json not found after generation"
fi

exit 0
