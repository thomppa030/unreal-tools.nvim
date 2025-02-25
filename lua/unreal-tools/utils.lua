local M = { }

function M.get_subdirectories(path)
  local handle = vim.loop.fs_scandir(path)
  local dirs = { }


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

return M
