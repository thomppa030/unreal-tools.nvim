local M          = {}
local detection  = require("unreal-tools.detection")
local terminal   = require("unreal-tools.terminal")
local utils      = require("unreal-tools.utils")

M.active_builds  = {}

M.targets        = {
  EDITOR = "Editor",
  GAME = "Game",
  CLIENT = "Client",
  SERVER = "Server",
}

M.configurations = {
  DEVELOPMENT = "Development",
  SHIPPING = "Shipping",
  TEST = "Test",
  DEBUG = "Debug",
  DEBUGGAME = "DebugGame",
}

M.platforms      = {
  WINDOWS = "Win64",
  LINUX = "Linux",
  MAC = "Mac",
  ANDROID = "Android",
  IOS = "IOS",
}

function M.build_options(project, opts)
  opts = opts or {}

  local default_platform
  local os_name = vim.loop.os_uname().sysname

  if os_name == "Windows" then
    default_platform = M.platforms.WINDOWS
  elseif os_name == "Darwin" then
    default_platform = M.platforms.MAC
  else
    default_platform = M.platforms.LINUX
  end

  local options = {
    project_name = project.name,
    project_path = project.path,
    uproject_path = project.path .. "/" .. project.name .. ".uproject",
    target = opts.target or M.targets.EDITOR,
    configuration = opts.configuration or M.configurations.DEVELOPMENT,
    platform = opts.platform or default_platform,
    arguments = opts.arguments or "",
    build_engine = opts.build_engine ~= nil and opts.build_engine or true,
    additional_args = opts.additional_args or "",
  }
  return options
end

function M.get_build_script(engine_path, platform)
  if platform == M.platforms.WINDOWS then
    return engine_path .. "/Engine/Build/BatchFiles/Build.bat"
  else
    return engine_path .. "/Engine/Build/BatchFiles/Linux/Build.sh"
  end
end

function M.construct_build_command(engine_path, options)
  local build_script = M.get_build_script(engine_path, options.platform)
  local engine_arg = options.build_engine and " -engine" or ""

  local cmd = build_script ..
      " -project=\"" .. options.uproject_path .. "\"" ..
      " " .. options.project_name .. options.target ..
      " " .. options.platform ..
      " " .. options.configuration ..
      " " .. engine_arg ..
      " " .. options.additional_args

  return cmd
end

M.error_patterns = {
  -- C++ compilation errors
  {
    pattern = "error[%s]*:[%s]*([^:]+):(%d+):(%d+):[%s]*(.+)",
    handler = function(match, build)
      local file, line, col, error_msg = match[1], match[2], match[3], match[4]

      table.insert(build.errors, {
        type = "error",
        file = file,
        line = tonumber(line),
        col = tonumber(col),
        message = error_msg,
        full_line = match[0],
      })
    end
  },

  -- UBT errors
  {
    pattern = "Error:[%s]*([^%(]+)%((%d+)%):[%s]*(.+)",
    handler = function(match, build)
      local file, line, error_msg = match[1], match[2], match[3]

      table.insert(build.errors, {
        type = "error",
        file = file,
        line = tonumber(line),
        col = 1,
        message = error_msg,
        full_line = match[0],
      })
    end
  },
  -- Warning pattern
  {
    pattern = "error[%s]*:[%s]*([^:]+):(%d+):(%d+):[%s]*(.+)",
    handler = function(match, build)
      local file, line, col, warning_msg = match[1], match[2], match[3], match[4]

      table.insert(build.errors, {
        type = "warning",
        file = file,
        line = tonumber(line),
        col = tonumber(col),
        message = warning_msg,
        full_line = match[0],
      })
    end
  },
}

function M.new_build(project, opts)
  opts = opts or {}

  local engine_path = detection.find_engine_path(opts.config or {})
  if not engine_path then
    vim.notify("unreal-tools: Cannot build project - UE engine path not found", vim.log.levels.ERROR)
    return nil
  end

  local build_options = M.build_options(project, opts)

  local build = {
    id = terminal.generate_terminal_id("build"),
    project = project,
    options = build_options,
    engine_path = engine_path,
    start_time = nil,
    end_time = nil,
    duration = nil,
    success = nil,
    exit_code = nil,
    errors = {},
    warnings = {},
    terminal = nil,
    on_complete = opts.on_complete,
    on_error = opts.on_error,
    on_success = opts.on_success,
    cancel_requested = false,
  }

  M.active_builds[build.id] = build

  local process_output = function(line, terminal)
    for _, pattern_def in ipairs(M.error_patterns) do
      local match = { line:match(pattern_def.pattern) }
      if #match > 0 then
        match[0] = line
        pattern_def.handler(match, build)
      end
    end
  end

  build.terminal = terminal.new_terminal({
    id = build.id,
    title = "UE Build: " .. build_options.project_name .. build_options.target,
    direction = opts.direction or "horizontal",
    close_on_exit = opts.close_on_exit or false,
    on_output = process_output,
    on_exit = function(code, term)
      build.exit_code = code
      build.end_time = os.time()
      build.duration = build.end_time - (build.start_time or build.end_time)
      build.success = code == 0

      if build.success then
        vim.notify(
          string.format(
            "unreal-tools: %s%s built successfully (time: %ds)",
            build_options.project_name,
            build_options.target,
            build.duration
          ),
          vim.log.levels.INFO
        )
      else
        vim.notify(
          string.format(
            "unreal-tools: Failed to build %s%s (exit code: %d, time: %ds)",
            build_options.project_name,
            build_options.target,
            code,
            build.duration
          ),
          vim.log.levels.ERROR
        )
      end

      if build.on_success then
        build.on_success()
      end


      if #build.errors > 0 then
        M.populate_quickfix(build)
      end

      if build.on_error then
        build.on_error(build)
      end

      if build.on_complete then
        build.on_complete(build)
      end
    end,

    patterns = {
      ["Error"] = function(line, term)
        -- handled by the main process funtion?
      end,
    },
  })

  build.start = function()
    local cmd = M.construct_build_command(engine_path, build_options)

    build.terminal.open()

    build.start_time = os.time()

    build.terminal.start(cmd)

    return true
  end

  build.cancel = function()
    build.cancel_requested = true
    return build.terminal.stop()
  end

  build.show_errors = function()
    M.populate_quickfix(build)
  end

  return build
end

function M.populate_quickfix(build)
  if #build.errors == 0 and #build.warnings == 0 then
    vim.notify("No errors or warnings to display", vim.log.levels.INFO)
    return
  end

  local qf_items = {}

  for _, err in ipairs(build.errors) do
    table.insert(qf_items, {
      filename = err.file,
      lnum = err.line,
      col = err.col,
      text = "[Error] " .. err.message,
      type = "E",
    })
  end

  for _, warn in ipairs(build.warnings) do
    table.insert(qf_items, {
      filename = warn.file,
      lnum = warn.line,
      col = warn.col,
      text = "[Warning] " .. warn.message,
      type = "W",
    })
  end

  vim.fn.setqflist(qf_items, "r")

  if #qf_items > 0 then
    vim.cmd("copen")
    vim.notify(string.format("Found %d errors and %d warnings", #build.errors, #build.warnings), vim.log.levels.WARN)
  end
end

function M.build_editor(config, project, opts)
  opts = opts or {}
  opts.target = M.targets.EDITOR
  opts.config = config

  local build = M.new_build(project, opts)
  if not build then
    return false
  end

  return build.start()
end

function M.start_editor(config, project, opts)
  local engine_path = detection.find_engine_path(config)
  if not engine_path then
    vim.notify("unreal-tools: Cannot start editor - UE Engine path not found", vim.log.levels.ERROR)
    return false
  end

  opts = opts or {}

  local project_name = project.name
  local project_path = project.path
  local uproject_path = project.path .. "/" .. project.name .. ".uproject"

  if not utils.file_exists(uproject_path) then
    vim.notify("unreal-tools: Cannot find .uproject file at " .. uproject_path, vim.log.levels.ERROR)
    return false
  end

  local os_name = vim.loop.os_uname().sysname

  local editor_binary

  if os_name == "Windows" then
    editor_binary = engine_path .. "/Engine/Binaries/Win64/UnrealEditor.exe"
  elseif os_name == "Darwin" then
    editor_binary = engine_path .. "/Engine/Binaries/Mac/UnrealEditor"
  else
    editor_binary = engine_path .. "/Engine/Binaries/Linux/UnrealEditor"
  end

  if not utils.file_exists(editor_binary) then
    vim.notify("unreal-tools: Cannot find UnrealEditor binary at " .. editor_binary, vim.log.levels.ERROR)
    return false
  end

  local editor_args = opts.editor_args or ""
  local cmd = editor_binary .. " \"" .. uproject_path .. "\" " .. editor_args

  local term = terminal.new_terminal({
    title = "UE Run: " .. project_name .. "Editor",
    direction = opts.direction or "horizontal",
    close_on_exit = opts.close_on_exit or false,
    on_exit = function(code, term)
      if code == 0 then
        vim.notify("unreal-tools: UnrealEditor closed successfully", vim.log.levels.INFO)
      else
        vim.notify("unreal-tools: UnrealEditor exited with code ", vim.log.levels.WARN)
      end

      if opts.on_exit then
        opts.on_exit(code)
      end
    end
  })

  term.open()
  term.start(cmd)

  vim.notify("unreal-tools: Starting UnrealEditor for project " .. project_name, vim.log.levels.INFO)

  return true
end

function M.build_and_start_editor(config, project, opts)
  opts = opts or {}

  local engine_path = detection.find_engine_path(config)
  if not engine_path then
    vim.notify("unreal-tools: Cannot build and start - UE engine path not found", vim.log.levels.ERROR)
    return false
  end

  local running, pids = utils.is_unreal_running(project)

  if running then
    local should_close = vim.fn.confirm(
      "Unreal Editor is already running for project '" .. project.name .. "'. Close it before starting a new instance?",
      "&Yes\n&No", 1)

    if should_close == 1 then
      if not utils.close_unreal(pids) then
        vim.notify("unreal-tools: Failed to close existing Unreal Editor instance", vim.log.levels.ERROR)
        return false
      end
    else
      vim.notify("unreal-tools: Canceled starting new Unreal Editor instance", vim.log.levels.WARN)
      return false
    end
  end

  return M.build_editor(config, project, {
    on_success = function(build)
      M.start_editor(config, project, opts)
    end,
    direction = opts.direction or "horizontal",
    close_on_exit = true,
    close_immediately = true,
  })
end

return M
