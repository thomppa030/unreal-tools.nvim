local M = {}

function M.setup(config, project)
  local prefix = config.keymap_prefix

  vim.keymap.set('n', prefix .. 'os', 'UEOpenSourceDir<CR>', { desc = 'Open Source directory' })
  vim.keymap.set('n', prefix .. 'oc', 'UEOpenContentDir<CR>', { desc = 'Open Source directory' })

  vim.keymap.set('n', prefix .. 'gc', 'UEGenerateCompileCommands<CR>', { desc = 'Generates UE compile commands' })

  local opts = { noremap = true, silent = true }
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)

  vim.keymap.set('n', '<leader>-', ':b#<CR>', { noremap = true, silent = true, desc = "Switch Back to last used Buffer"})


  vim.keymap.set('n', prefix .. 'hs', 'UESwitchHeaderSource<CR>', { desc = 'Switches between Header/Source file' })
end

return M
