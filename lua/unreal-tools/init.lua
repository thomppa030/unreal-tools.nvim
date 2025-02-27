local M = {}

M.config = require('unreal-tools.config').defaults
M.initialized = false
M.required_nvim_version = '0.10.0'

M.dependencies = {
  { name = "lspconfig",      optional = false },
  { name = "telescope.nvim", optional = true },
  { name = "plenary.nvim",   optional = true },
}

function M.check_nvim_version()
  local version = vim.version()
  local current_version = string.format('%d.%d.%d', version.major, version.minor, version.patch)

  if current_version < M.required_nvim_version then
    vim.notify(
      string.format(
        "unreal-tools requires Neovim >= %s (current: %s)",
        M.required_nvim_version,
        current_version
      ),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

function M.check_dependencies()
  local missing_deps = {}

  for _, dep in ipairs(M.dependencies) do
    local has_dep = pcall(require, dep.name)
    if not has_dep and not dep.optional then
      table.insert(missing_deps, dep.name)
    end
  end

  if #missing_deps > 0 then
    vim.notify("unreal tools is missing required dependencies: " .. table.concat(missing_deps, ", "),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

function M.validate_config(config)
  if type(config.ue_paths) ~= "table" then
    vim.notify("unreal-tools: config.ue_paths must be a table", vim.log.levels.ERROR)
    return false
  end

  if config.lsp.enable and type(config.lsp.clangd_args) ~= "table" then
    vim.notify("unreal-tools: config.lsp.clangd_args must be a table", vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.teardown()
  vim.notify("unreal-tools: Plugin deactivated", vim.log.levels.INFO)
  M.initialized = false
end

function M.setup(opts)
  if M.initialized then
    return M
  end

  if not M.check_nvim_version() then
    return M
  end

  if not M.check_dependencies() then
    return M
  end

  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  if not M.validate_config(M.config) then
    return M
  end

  local detection = require('unreal-tools.detection')
  local lsp = require('unreal-tools.lsp')
  local telescope = require('unreal-tools.telescope')
  local commands = require('unreal-tools.commands')
  local keymaps = require('unreal-tools.keymaps')

  M.augroup = vim.api.nvim_create_augroup("UnrealTools", { clear = true })

  local is_ue_project, reason = detection.is_unreal_project()

  if is_ue_project then
    M.project = {
      name = detection.get_project_name(),
      path = vim.fn.getcwd(),
      source_dir = vim.fn.getcwd() .. "/Source",
      content_dir = vim.fn.getcwd() .. "/Content",
      engine_path = detection.find_engine_path(M.config),
      engine_version = detection.get_engine_version(M.config)
    }

    if not M.project.engine_path then
      vim.notify(
        "unreal-tools: Cannot find Unreal Engine path. Please check your configuration.",
        vim.log.levels.ERROR
      )
      return M
    end

    local setup_components = {
      { name = "LSP",       fn = function() lsp.setup(M.config, M.project) end },
      { name = "Telescope", fn = function() telescope.setup(M.config, M.project) end },
      { name = "Commands",  fn = function() commands.setup(M.config, M.project) end },
      {
        name = "Keymaps",
        fn = function()
          if M.config.use_keymaps then
            keymaps.setup(M.config, M.project)
          end
        end
      },
    }

    for _, component in ipairs(setup_components) do
      local success, err = pcall(component.fn)
      if not success then
        vim.notify(
          string.format("unreal-tools: Failed to initialize %s component: %s", component.name, err),
          vim.log.levels.ERROR
        )
      end
    end

    vim.notify(
      string.format(
        "unreal-tools: Unreal Project '%s' (UE %s) detected and configured",
        M.project.name,
        M.project.engine_version or "unknown version"
      ),
      vim.log.levels.INFO
    )
    M.initialized = true
  end
  return M
end

function M.diagnose()
  local diagnosis = {
    nvim_version = vim.version(),
    initialized = M.initialized,
    dependencies = {},
    config = vim.deepcopy(M.config),
    project = M.initialized and vim.deepcopy(M.project) or nil,
  }

  for _, dep in ipairs(M.dependencies) do
    local has_dep = pcall(require, dep.name)
    diagnosis.dependencies[dep.name] = {
      installed = has_dep,
      required = not dep.optional
    }
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "unreal-tools-diagnosis")

  local lines = {
    "# unreal-tools Diagnosis",
    "",
    string.format("Neovim Version: %d.%d.%d", diagnosis.nvim_version.major, diagnosis.nvim_version.minor,
      diagnosis.nvim_version.patch),
    string.format("Plugin Initialized: %s", diagnosis.initialized and "Yes" or "No"),
    "",
    "## Dependencies",
  }

  for name, status in pairs(diagnosis.dependencies) do
    table.insert(
      lines,
      string.format("- %s: %s %s",
        name,
        status.installed and "✓" or "✗",
        status.required and "(Required)" or "(Optional)"
      )
    )
  end

  table.insert(lines, "")
  table.insert(lines, "## Project Information")

  if diagnosis.project then
    table.insert(lines, string.format("- Name: %s", diagnosis.project.name))
    table.insert(lines, string.format("- Path: %s", diagnosis.project.path))
    table.insert(lines, string.format("- Engine Path: %s", diagnosis.project.engine_path or "Not found"))
    table.insert(lines, string.format("- Engine Version: %s", diagnosis.project.engine_version or "Unknown"))
  else
    table.insert(lines, "- No Unreal project detected or plugin not initialized")
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  return diagnosis
end

function M.reload()
  if M.initialized then
    M.teardown()
  end

  for k, _ in pairs(package.loaded) do
    if k:match("^unreal%-tools") then
      package.loaded[k] = nil
    end
  end

  return require('unreal-tools').setup(M.config)
end

return M
