local M = {}

local utils = require('nvim-unreal.utils')

function M.is_unreal_project()
  local path = vim.fn.getcwd()

  local project_name = vim.fn.fnamemodify(path, ":t")
  if vim.fn.filereadable(path .. "/" .. project_name .. ".uproject") == 1 then
    return true
  end

  local uproject_files = vim.fn.glob(path .. "/*.uproject", false, true)
  if #uproject_files > 0 then
    return true
  end

  if vim.fn.isdirectory(path .. "/Source") == 1 and vim.fn.isdirectory(path .."/Content") == 1 then
    return true
  end

  return false
end

function M.get_project_name()
  local path = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(path, ":it")

  if vim.fn.filereadable(path .. "/" .. project_name .. ".uproject") == 1 then
    return project_name
  end

  local uproject_files = vim.fn.glob(path .. "/*.uproject", false, true)
  if #uproject_files > 0 then
    return vim.fn.fnamemodify(uproject_files[1], ":t:r")
  end

  return project_name
end

-- Find the UE Engine path from the config
function M.find_engine_path(config)
  -- If a specific version is requested, look for it
  if config.ue_version then
    for _, base_path in pairs(config.ue_paths) do
      local versioned_path = base_path .. "_" .. config.ue_version
      if vim.fn.isdirectory(versioned_path) == 1 then
        return versioned_path
      end
    end
  end

  -- Otherwise check all configured ue_paths
  for _,  path in ipairs(config.ue_paths) do
    if vim.fn.isdirectory(path) == 1 then
      local versions = utils.get_subdirectories(path)
      table.sort(versions, function(a,b) return a > b end) -- sort descending for latest version

      for _, version in ipairs(versions) do
        if version:match("^%d+%.%d+$") then
          return path .. "/" .. version
        end
      end

      -- If we didn't find a version subfolder, the base_path might be the Engine
      return path
    end
  end

  vim.notify("Unreal-tools: Couldn't find a valid Unreal Engine installation path.", vim.log.levels.WARN)
  vim.notify("Please configure your UE path in Unreal-tools setup()", vim.log.levels.WARN)

  return nil
end

return M
