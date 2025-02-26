local M = {}

function M.get_subdirectories(path)
  local handle = vim.loop.fs_scandir(path)
  local dirs = {}


  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end

      if type == "directory" then
        table.insert(dirs, name)
      end
    end
  end

  return dirs
end

function M.file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

function M.execute_commands(cmd)
  local handle = io.popen(cmd)
  if not handle then return "" end

  local result = handle:read("*a")
  handle:close()
  return result
end

function M.is_unreal_running(project)
  -- Run the command to find Unreal Engine processes for this project
  local cmd = "pgrep -f 'UnrealEditor.*" .. project.name .. "'"
  local handle = io.popen(cmd)

  if not handle then
    return false, nil
  end

  local result = handle:read("*a")
  handle:close()

  -- If we got a process ID, Unreal is running
  if result and result ~= "" then
    -- Split by newlines to handle multiple instances
    local pids = {}
    for pid in result:gmatch("([^\n]+)") do
      table.insert(pids, pid)
    end
    return true, pids
  end

  return false, nil
end

function M.close_unreal(pids)
  if not pids or #pids == 0 then
    return true
  end

  vim.notify("unreal-tools: Closing running Unreal Editor instance(s)...", vim.log.levels.INFO)

  -- First try SIGTERM for a clean shutdown
  for _, pid in ipairs(pids) do
    os.execute("kill " .. pid)
  end

  -- Give it a few seconds to close cleanly
  vim.notify("unreal-tools: Waiting for Unreal Editor to close...", vim.log.levels.INFO)
  vim.cmd("sleep 5000m") -- Sleep for 3 seconds

  -- Check if it's still running
  for _, pid in ipairs(pids) do
    local check_cmd = "ps -p " .. pid .. " -o pid="
    local handle = io.popen(check_cmd)
    local result = handle:read("*a")
    handle:close()

    -- If the process is still running, force kill it
    if result and result ~= "" then
      vim.notify("unreal-tools: Unreal Editor didn't close gracefully, forcing close...", vim.log.levels.WARN)
      os.execute("kill -9 " .. pid)
    else
      vim.notify("unreal-tools: Unreal Editor closed successfully", vim.log.levels.INFO)
      return true
    end
  end

  -- Give another brief moment for OS to clean up
  vim.cmd("sleep 1000m") -- Sleep for 1 second

  for _, pid in ipairs(pids) do
    local check_cmd = "ps -p " .. pid .. " -o pid="
    local handle = io.popen(check_cmd)
    local result = handle:read("*a")
    handle:close()

    if result and result ~= "" then
      vim.notify("unreal-tools: Failed to close Unreal Editor completely", vim.log.levels.ERROR)
      return false
    else
      vim.notify("unreal-tools: Unreal Editor closed successfully", vim.log.levels.INFO)
      return true
    end
  end
end

return M
