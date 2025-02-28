local M = {}

M.cache = {}
M.cache_ttl = {} -- Time-to-live for cache entries (in seconds)
M.default_ttl = 300

function M.set_cache(key, value, ttl)
  M.cache[key] = value
  M.cache_ttl[key] = os.time() + (ttl or M.default_ttl)
end

function M.get_cache(key)
  if M.cache_ttl[key] and os.time() > M.cache_ttl[key] then
    M.cache[key] = nil
    M.cache_ttl[key] = nil
    return nil
  end

  return M.cache[key]
end

function M.has_cache(key)
  return M.cache[key] ~= nil and (not M.cache_ttl[key] or os.time() <= M.cache_ttl[key])
end

function M.clear_cache(key)
  if key then
    M.cache[key] = nil
    M.cache_ttl[key] = nil
  else
    M.cache = {}
    M.cache_ttl = {}
  end
end

function M.get_subdirectories(path)
  local dirs = {}

  local success, handle = pcall(vim.loop.fs_scandir, path)

  if success and handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end

      if type == "directory" then
        table.insert(dirs, name)
      end
    end
    return dirs
  end

  local cmd = "find " .. vim.fn.shellescape(path) .. "-maxdepth 1 -type d -not - path " .. vim.fn.shellescape(path)
  local handle = io.popen(cmd)

  if not handle then
    vim.notify("unreal-tools: Failed to scan directory: " .. path, vim.log.levels.ERROR)
    return {}
  end

  local result = handle:read("*a")
  handle:close()

  for dir in result:gmatch("([^\n]+)") do
    local dir_name = vim.fn.fnamemodify(dir, ":t")
    if dir_name and dir_name ~= "" then
      table.insert(dirs, dir_name)
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

function M.dir_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "directory" or false
end

function M.execute_command(cmd, opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or 5000
  local show_output = opts.show_output or false

  local tmp_file = os.tmpname()
  local full_cmd = cmd .. " > " .. tmp_file .. "2>&1"

  local pid = vim.fn.jobstart(full_cmd, {
    detach = true,
  })

  if pid <= 0 then
    os.remove(tmp_file)
    return nil, "Failed to start command"
  end

  local start_time = vim.loop.now()
  local exit_code = nil

  while vim.loop.now() - start_time < timeout_ms do
    exit_code = vim.fn.jobwait({ pid }, 100)[1]
    if exit_code ~= -1 then
      break
    end
  end

  if exit_code == -1 then
    vim.fn.jobstop(pid)
    os.remove(tmp_file)
    return nil, "Command timed out after " .. (timeout_ms / 1000) .. " seconds"
  end

  local file = io.open(tmp_file, "r")
  local output = ""

  if file then
    output = file:read("*a")
    file:close()
  end

  os.remove(tmp_file)

  if show_output and output ~= "" then
    vim.notify(output, exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
  end

  return exit_code == 0, output
end

function M.is_unreal_running(project)
  -- Run the command to find Unreal Engine processes for this project
  local cache_key = "unreal_running:" .. project.name

  if M.has_cache(cache_key) then
    return M.get_cache(cache_key)
  end

  local pids = {}
  local cmd

  local os_name = vim.loop.os_uname().sysname
  if os_name == "Windows" then
    cmd = "wmic process where \"caption like 'UnrealEditor%' and commandline like '%" ..
        project.name .. "%'\" get processid"
  elseif os_name == "Darwin" then
    cmd = "pgrep -f 'UnrealEditor.*'" .. project.name .. "'"
  else
    cmd = "pgrep -f 'UnrealEditor.*'" .. project.name .. "'"
  end

  local success, output = M.execute_command(cmd)

  if success and output and output ~= "" then
    for pid in output:gmatch("(%d+)") do
      table.insert(pids, pid)
    end
  end

  local result = #pids > 0 --, pids
  M.set_cache(cache_key, { result, pids }, 5)

  return result, pids
end

function M.close_unreal(pids)
  if not pids or #pids == 0 then
    return true
  end

  vim.notify("unreal-tools: Closing running Unreal Editor instance(s)...", vim.log.levels.INFO)

  local os_name = vim.loop.os_uname().sysname
  local cmd_prefix = os_name == "Windows" and "taskkill " or "kill "
  local force_flag = os_name == "Windows" and "/f " or "-9 "

  for _, pid in ipairs(pids) do
    local cmd = cmd_prefix .. pid
    local success = M.execute_command(cmd)

    if not success then
      vim.notify("unreal-tools: Failed to gracefully close Unreal Editor (PID): " .. pid .. ")", vim.log.levels.WARN)
    end
  end

  vim.defer_fn(function()
    local still_running = false

    for _, pid in ipairs(pids) do
      local check_cmd

      if os_name == "Windows" then
        check_cmd = "tasklist /FI \"PID eq " .. pid .. "\" /NH"
      else
        check_cmd = "ps -p " .. pid .. " -o pid="
      end

      local success, output = M.execute_command(check_cmd)

      if success and output and output:find(pid) then
        still_running = true

        local force_cmd = cmd_prefix .. force_flag .. pid
        local force_success, _ = M.execute_command(force_cmd)

        if not force_success then
          vim.notify("unreal-tools: Failed to gracefully close Unreal Editor (PID): " .. pid .. ")", vim.log.levels.WARN)
          return false
        end
      end
    end

    if still_running then
          vim.notify("unreal-tools: Forcefully terminated Unreal Editor processes", vim.log.levels.WARN)
    else
          vim.notify("unreal-tools: Unreal Editor closed successfully", vim.log.levels.WARN)
    end
  end, 3000)

  return true
end

return M
