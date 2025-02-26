local M = {}

function M.setup(config, project)
  local prefix = config.keymap_prefix

  vim.keymap.set('n', prefix .. 'os', 'UEOpenSourceDir<CR>', {desc = 'Open Source directory'})
  vim.keymap.set('n', prefix .. 'oc', 'UEOpenContentDir<CR>', {desc = 'Open Source directory'})

  vim.keymap.set('n', prefix .. 'gc', 'UEGenerateCompileCommands<CR>', {desc = 'Generates UE compile commands'})

  vim.keymap.set('n', prefix .. 'hs', 'UESwitchHeaderSource<CR>', {desc = 'Switches between Header/Source file'})

end

return M
