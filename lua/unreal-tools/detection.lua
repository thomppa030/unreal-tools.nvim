local M = {}

local utils = require('unreal-tools.utils')


M.ENGINE_MARKERS = {
  BINARIES = "/Engine/Binaries",
  SOURCE = "/Engine/Source",
  CONFIG = "/Engine/Config",
}

function M.is_valid_engine_dir(path)
  return utils.dir_exists(path .. M.ENGINE_MARKERS.BINARIES)
end

function M.find_engine_in_parents(start_path, depth)
  depth = depth or 2
  local current_path = start_path

  if M.is_valid_engine_dir(current_path) then
    return current_path
  end

  for i = 1, depth do
    current_path = vim.fn.fnamemodify(current_path, ":h")
    if M.is_valid_engine_dir(current_path) then
      return current_path
    end
  end

  return nil
end

function M.is_project_in_engine_directory()
  return M.find_engine_in_parents(vim.fn.getcwd()) ~= nil
end

function M.get_engine_registry_path()
  local os_name = vim.loop.os_uname().sysname

  if os_name == "Linux" then
    local home = os.getenv("HOME")
    if home then
      local path = home .. "/.config/Epic/UnrealEngine/Install.ini"
      if utils.file_exists(path) then
        return path
      end
    end
  end
end

--
-- There are several ways Epic Games supports Projects and Associations
-- All possibilities should be covered here
-- https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Projects/FProjectDescriptor/EngineAssociation

function M.parse_engine_registry(registry_path)
  local installations = {}

  if not registry_path or not utils.file_exists(registry_path) then
    return installations
  end

  local file = io.open(registry_path, "r")
  if not file then
    return installations
  end

  local in_installations_section = false

  for line in file:lines() do
    if line == "[Installations]" then
      in_installations_section = true
    elseif line:match("^%[.*%]$") then
      in_installations_section = false
    elseif in_installations_section then
      local guid, path = line:match("([^=]+)=(.+)")
      if guid and path then
        installations[guid] = path
      end
    end
  end

  file:close()
  return installations
end

function M.is_guid_format(str)
  return str and str:match("^{%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x}$") ~= nil
end

function M.get_version_path_patterns(base_path, version)
  return {
    base_path .. "_" .. version, -- UnrealEngine_5.3
    base_path .. "-" .. version, -- UnrealEngine-5.3
    base_path .. "/" .. version, -- UnrealEngine/5.3
    base_path                    -- plain path
  }
end

function M.get_common_source_paths()
  local home = os.getenv("HOME")
  return {
    home .. "/UnrealEngine",
    home .. "/dev/UnrealEngine",
    "/opt/UnrealEngine",
  }
end

function M.get_common_versioned_paths(version)
  local home = os.getenv("HOME")
  return {
    home .. "/.local/share/Epic/UE_" .. version,
    "/opt/UnrealEngine/" .. version,
  }
end

function M.get_engine_version(config)
  if M.is_project_in_engine_directory() then
    return "Source"
  end

  if config.ue_version then
    return config.ue_version
  end

  local uproject_data, err = M.parse_uproject_file()
  if not uproject_data then
    vim.notify("unreal-tools: " .. (err or "Unknown parsing error parsing .uproject"), vim.log.levels.ERROR)
    return nil
  end

  if not uproject_data.EngineAssociation or uproject_data.EngineAssociation == "" then
    return nil
  end

  local engine_association = uproject_data.EngineAssociation

  if M.is_guid_format(engine_association) then
    return "Source"
  end

  return engine_association
end

function M.find_engine_path(config)
  local cache_key = "engine path:" .. vim.fn.getcwd()

  if utils.has_cache(cache_key) then
    return utils.get_cache(cache_key)
  end

  local engine_version = M.get_engine_version(config)

  if engine_version == "Source" then
    local engine_dir = M.find_engine_in_parents(vim.fn.getcwd())
    if engine_dir then
      utils.set_cache(cache_key, engine_dir)
      return engine_dir
    end

    local uproject_data = M.parse_uproject_file()
    if uproject_data and uproject_data.EngineAssociation and M.is_guid_format(uproject_data.EngineAssociation) then
      local guid = uproject_data.EngineAssociation

      local registry_path = M.get_engine_registry_path()
      if registry_path then
        local installations = M.parse_engine_registry(registry_path)
        if installations[guid] and M.is_valid_engine_dir(installations[guid]) then
          utils.set_cache(cache_key, installations[guid])
          return installations[guid]
        end
      end
    end

    for _, path in ipairs(M.get_common_source_paths()) do
      if M.is_valid_engine_dir(path) then
        utils.set_cache(cache_key, path)
        return path
      end
    end

    -- We look in user-defined paths
    for _, path in ipairs(config.ue_paths) do
      if M.is_valid_engine_dir(path) then
        utils.set_cache(cache_key, path)
        return path
      end
    end

    vim.notify("unreal-tools: Source build specified but couldn't locate the engine directory", vim.log.levels.WARN)
    return nil
  elseif engine_version then
    for _, base_path in ipairs(config.ue_paths) do
      for _, path_pattern in ipairs(M.get_version_path_patterns(base_path, engine_version)) do
        if utils.dir_exists(path_pattern) and M.is_valid_engine_dir(path_pattern) then
          utils.set_cache(cache_key, path_pattern)
          return path_pattern
        end
      end
    end
    for _, path in ipairs(M.get_common_versioned_paths(engine_version)) do
      if utils.dir_exists(path) and M.is_valid_engine_dir(path) then
        utils.set_cache(cache_key, path)
        return path
      end
    end
  end

  vim.notify("unreal-tools: Couldn't find a valid Unreal Engine installation path.", vim.log.levels.WARN)
  vim.notify("Please configure your UE path in unreal-tools setup()", vim.log.levels.WARN)

  return nil
end

function M.parse_uproject_file()
  local path = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(path, ":t")
  local uproject_path = path .. "/" .. project_name .. ".uproject"

  if vim.fn.filereadable(uproject_path) ~= 1 then
    local uproject_files = vim.fn.glob(path .. "/*.uproject", false, true)
    if #uproject_files > 0 then
      uproject_path = uproject_files[1]
    else
      return nil, "No .uproject file found"
    end
  end

  local file = io.open(uproject_path, "r")
  if not file then
    return nil, "Failed to open .uproject file"
  end

  local content = file:read("*a")
  file:close()

  local success, json_data = pcall(vim.fn.json_decode, content)
  if not success or not json_data then
    return nil, "Failed to parse .uproject JSON"
  end

  return json_data, nil
end

function M.get_project_name()
  local path = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(path, ":t")

  if vim.fn.filereadable(path .. "/" .. project_name .. ".uproject") == 1 then
    return project_name
  end

  local uproject_files = vim.fn.glob(path .. "/*.uproject", false, true)
  if #uproject_files > 0 then
    return vim.fn.fnamemodify(uproject_files[1], ":t:r")
  end

  return project_name
end

function M.is_unreal_project()
  local path = vim.fn.getcwd()

  local project_name = vim.fn.fnamemodify(path, ":t")

  if vim.fn.filereadable(path .. "/" .. project_name .. ".uproject") == 1 then
    return true, "Found matching .uproject file"
  end

  local uproject_files = vim.fn.glob(path .. "/*.uproject", false, true)
  if #uproject_files > 0 then
    return true, "Found .uproject file"
  end

  if vim.fn.isdirectory(path .. "/Source") == 1 and vim.fn.isdirectory(path .. "/Content") == 1 then
    return true, "Found Source and Content directories"
  end

  local build_files = vim.fn.glob(path .. "/Source/*/*.Build.cs", true, true)
  if #build_files > 0 then
    return true, "Found .Build.cs files in Source directory"
  end

  local reasons = {}

  if vim.fn.isdirectory(path .. "/Source") == 0 then
    table.insert(reasons, "No Source directory found")
  end
  if vim.fn.isdirectory(path .. "/Content") == 0 then
    table.insert(reasons, "No Content directory found")
  end
  if #uproject_files == 0 then
    table.insert(reasons, "No .uproject file found")
  end

  return false, table.concat(reasons, ", ")
end

return M

