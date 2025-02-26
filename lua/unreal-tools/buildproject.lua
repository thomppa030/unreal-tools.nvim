local M         = {}
local detection = require("unreal-tools.detection")
local terminal  = require("unreal-tools.terminal")
local utils     = require("unreal-tools.utils")

function M.build_editor(config, project)
  local engine_path = detection.find_engine_path(config)
  if not engine_path then
    vim.notify("unreal-tools: Cannot build project - UE engine path not found", vim.log.levels.ERROR)
    return false
  end

  local handle = io.popen("pgrep -f UnrealEditor")
  local editor_running = false

  if handle then
    local result = handle:read("*a")
    handle:close()
    editor_running = result and result ~= ""
  end

  local project_name = project.name
  local project_path = project.path

  local build_script = engine_path .. "/Engine/Build/BatchFiles/Linux/Build.sh"

  local cmd = build_script ..
      " -project=" ..
      project_path ..
      "/" ..
      project_name .. ".uproject" .. " " .. project_name .. "Editor" .. " -game -engine " .. "Linux" .. " Development"

  terminal.open_term_command(cmd, {
    title = "UE Build: " .. project_name .. "Editor",
    direction = "horizontal", -- Can be changed based on user preference
    close_on_exit = false
  })

  return true
end

function M.start_editor(config, project)
  local engine_path = detection.find_engine_path(config)
  if not engine_path then
    vim.notify("unreal-tools: Cannot build project - UE engine path not found", vim.log.levels.ERROR)
    return false
  end

  local project_name = project.name
  local project_path = project.path
  local uproject_path = project.path .. "/" .. project_name .. ".uproject"

  local editor_binary = engine_path .. "/Engine/Binaries/Linux/UnrealEditor"

  local cmd = editor_binary .. " \"" .. uproject_path .. "\""

  terminal.open_term_command(cmd, {
    title = "UE Run: " .. project_name .. "Editor",
    direction = "horizontal",
    close_on_exit = false,
  })
end

function M.build_and_start_editor(config, project)
  -- Get the Unreal Engine path
  local engine_path = detection.find_engine_path(config)
  if not engine_path then
    vim.notify("unreal-tools: Cannot build and start - UE engine path not found",
      vim.log.levels.ERROR)
    return false
  end

  -- Get project details
  local project_name = project.name
  local project_path = project.path

  -- Build script path
  local build_script = engine_path .. "/Engine/Build/BatchFiles/Linux/Build.sh"

  local running, pids = utils.is_unreal_running(project)

  if running then
    local should_close = vim.fn.confirm(
      "Unreal Editor is already running for project '" .. project_name .. "'. Close it before starting a new instance?",
      "&Yes\n&No", 1)

    if should_close == 1 then
      if not utils.close_unreal(pids) then
        vim.notify("unreal-tools: Failed to close existing Unreal Editor instance", vim.log.levels.ERROR)
        return false
      end
    else
      vim.notify("unreal-tools: cancelled starting new Unreal Editor instance", vim.log.levels.ERROR)
      return false
    end
  end

  local cmd = build_script ..
      " -project=" ..
      project_path ..
      "/" ..
      project_name .. ".uproject" .. " " .. project_name .. "Editor" .. " -game -engine " .. "Linux" .. " Development"

  vim.notify("unreal-tools: Building " .. project_name .. "Editor...", vim.log.levels.INFO)

  -- Use jobstart to run the build asynchronously
  local build_job = vim.fn.jobstart(cmd, {
    cwd = project_path,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("unreal-tools: " .. project_name .. "Editor built successfully",
          vim.log.levels.INFO)
        -- Build successful, now start the editor
        M.start_editor(config, project)
      else
        vim.notify("unreal-tools: Failed to build " .. project_name .. "Editor (exit code: " .. code .. ")",
          vim.log.levels.ERROR)
      end
    end,
    stdout_buffered = false,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print("[Build] " .. line)
          end
        end
      end
    end,
    stderr_buffered = false,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print("[Build Error] " .. line)
          end
        end
      end
    end,
  })

  if build_job <= 0 then
    vim.notify("unreal-tools: Failed to start build job", vim.log.levels.ERROR)
    return false
  end

  return true
end

return M
