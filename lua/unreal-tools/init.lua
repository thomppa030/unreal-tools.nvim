local M = {}

M.config = require('unreal-tools.config').defaults
M.initialized = false

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  local detection = require('unreal-tools.detection')
  local lsp = require('unreal-tools.lsp')
  local telescope = require('unreal-tools.telescope')
  local snippets = require('unreal-tools.snippets')
  local commands = require('unreal-tools.commands')
  local keymaps = require('unreal-tools.keymaps')

  if detection.is_unreal_project() then
    M.project = {
      name = detection.get_project_name(),
      path = vim.fn.getcwd(),
      source_dir = vim.fn.getcwd() .. "/Source",
      content_dir = vim.fn.getcwd() .. "/Content",
    }

    lsp.setup(M.config, M.project)
    telescope.setup(M.config, M.project)
    snippets.setup(M.config, M.project)
    commands.setup(M.config, M.project)

    if M.config.use_keymaps then
      keymaps.setup(M.config, M.project)
    end

    vim.notify("Unreal-tools: Unreal Project '" .. M.project.name .. "' detected and configured",
      vim.log.levels.INFO)

    M.initialized = true
  else
    if M.config.notify_non_ue_project then
      vim.notify("Unreal-tools: Not an Unreal Project", vim.log.levels.Warn)
    end
  end
  return M
end

return M
