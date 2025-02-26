local M = {}

function M.open_term_command(cmd, opts)
  opts = opts or {}
  local term_opts = {
    direction = opts.direction or "float", -- Can be "float", "horizontal", "vertical", "tab"
    title = opts.title or "Unreal Engine",
    border = opts.border or "rounded",
    size = opts.size or 20,                     -- Height for horizontal, width for vertical
    close_on_exit = opts.close_on_exit or false -- Keep terminal open when process exits
  }

  -- Close any existing terminal with the same title
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):match("term://.*" .. vim.fn.shellescape(term_opts.title)) then
      vim.api.nvim_buf_delete(buf, { force = true })
      break
    end
  end

  -- Create the terminal in the appropriate location
  local buf, win
  if term_opts.direction == "float" then
    -- Create a floating window
    buf = vim.api.nvim_create_buf(false, true)

    -- Calculate window size
    local width = math.floor(vim.o.columns * 0.85)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Create the window with a border
    local opts = {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = term_opts.border,
      title = term_opts.title
    }

    win = vim.api.nvim_open_win(buf, true, opts)
  elseif term_opts.direction == "horizontal" then
    -- Create a horizontal split
    vim.cmd(term_opts.size .. "new")
    win = vim.api.nvim_get_current_win()
    buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_option(win, "winfixheight", true)
  elseif term_opts.direction == "vertical" then
    -- Create a vertical split
    vim.cmd(term_opts.size .. "vnew")
    win = vim.api.nvim_get_current_win()
    buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_option(win, "winfixwidth", true)
  elseif term_opts.direction == "tab" then
    -- Create a new tab
    vim.cmd("tabnew")
    win = vim.api.nvim_get_current_win()
    buf = vim.api.nvim_get_current_buf()
  end

  -- Set window options
  if term_opts.title and win then
    vim.wo[win].winblend = 10
    vim.api.nvim_win_set_option(win, "foldenable", false)
    vim.api.nvim_win_set_option(win, "wrap", true)
  end

  -- Start the terminal with the command
  vim.fn.termopen(cmd, {
    on_exit = function(_, code)
      if code == 0 then
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "[Process completed successfully]" })
      else
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "[Process exited with code " .. code .. "]" })
      end

      -- Optionally close the terminal after a delay
      if term_opts.close_on_exit then
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end, 3000) -- Wait 3 seconds before closing
      end
    end
  })

  -- Enter insert mode to allow immediate interaction with the terminal
  vim.cmd("startinsert")

  return buf, win
end

return M
