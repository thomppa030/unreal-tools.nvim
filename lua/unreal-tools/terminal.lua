local M = {}

M.active_terminals = {}

local terminal_counter = 0
function M.generate_terminal_id(prefix)
  terminal_counter = terminal_counter + 1
  return (prefix or "term") .. "_" .. os.time() .. "_" .. terminal_counter
end

M.config = {
  default_direction = "horizontal",
  default_size = 20,
  default_close_on_exit = false,
  default_close_immedeately = false,
  default_close_delay = 3000,
  default_border = "rounded",
  default_title = "Unreal Engine",
  output_buffer_size = 10000,
}

function M.new_terminal(opts)
  opts = opts or {}

  local term = {
    id = opts.id or M.generate_terminal_id(opts.prefix),
    title = opts.title or M.config.default_title,
    buffer = nil,
    window = nil,
    job_id = nil,
    output_lines = {},
    on_exit = opts.on_exit,
    on_output = opts.on_output,
    close_on_exit = opts.close_on_exit or M.config.default_close_on_exit,
    close_immediately = opts.close_immediately or M.config.default_close_immedeately,
    close_delay = opts.close_delay or M.config.default_close_delay,
    command = opts.command,
    cwd = opts.cwd or vim.fn.getcwd(),
    env = opts.env or {},
    patterns = opts.patterns or {},
  }

  term.open = function(direction, size)
    direction = direction or opts.direction or M.config.default_direction
    size = size or opts.size or M.config.default_size

    if M.active_terminals[term.id] and M.active_terminals[term.id].buffer and
        vim.api.nvim_buf_is_valid(M.active_terminals[term.id].buffer) then
      vim.api.nvim_buf_delete(M.active_terminals[term.id].buffer, { force = true })
    end

    if direction == "float" then
      term.buffer = vim.api.nvim_create_buf(false, true)

      local width = math.floor(vim.o.columns * 0.85)
      local height = math.floor(vim.o.lines * 0.8)
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)

      local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = opts.border or M.config.default_border,
        title = term.title,
        title_pos = "center",
      }

      term.window = vim.api.nvim_open_win(term.buffer, true, win_opts)
      vim.wo[term.window].winblend = 10
    elseif direction == "horizontal" then
      vim.cmd(size .. "new")
      term.window = vim.api.nvim_get_current_win()
      term.buffer = vim.api.nvim_get_current_buf()
      vim.api.nvim_win_set_option(term.window, "winfixheight", true)
    elseif direction == "vertical" then
      vim.cmd(size .. "vnew")
      term.window = vim.api.nvim_get_current_win()
      term.buffer = vim.api.nvim_get_current_buf()
      vim.api.nvim_win_set_option(term.window, "winfixwidth", true)
    elseif direction == "tab" then
      vim.cmd("tabnew")
      term.window = vim.api.nvim_get_current_win()
      term.buffer = vim.api.nvim_get_current_buf()
    end

    if term.window then
      vim.api.nvim_win_set_option(term.window, "foldenable", false)
      vim.api.nvim_win_set_option(term.window, "wrap", true)
      vim.api.nvim_win_set_option(term.window, "number", false)

      vim.api.nvim_buf_set_name(term.buffer, "terminal://" .. term.title)
    end

    M.active_terminals[term.id] = term

    return term
  end

  term.start = function(command)
    command = command or term.command

    if not command then
      vim.notify("No command specified for terminal", vim.log.levels.ERROR)
      return false
    end

    if not term.buffer or not vim.api.nvim_buf_is_valid(term.buffer) then
      term.open()
    end

    local process_output = function(_, data)
      if not data then return end

      for _, line in ipairs(data) do
        if line and line ~= "" then
          while #term.output_lines >= M.config.output_buffer_size do
            table.remove(term.output_lines, 1)
          end

          table.insert(term.output_lines, line)

          if term.patterns then
            for pattern, handler in pairs(term.patterns) do
              if line:match(pattern) then
                handler(line, term)
              end
            end
          end

          if term.on_output then
            term.on_output(line, term)
          end
        end
      end
    end

    term.job_id = vim.fn.termopen(command, {
      cwd = term.cwd,
      on_stdout = process_output,
      on_stderr = process_output,
      on_exit = function(_, code)
        if term.buffer and vim.api.nvim_buf_is_valid(term.buffer) then
          vim.api.nvim_buf_set_option(term.buffer, 'modifiable', true)
          if code == 0 then
            vim.api.nvim_buf_set_lines(term.buffer, -1, -1, false, { "", "[Process completed successfully]" })
          else
            vim.api.nvim_buf_set_lines(term.buffer, -1, -1, false, { "", "[Process exited with code " .. code .. "]" })
          end
          vim.api.nvim_buf_set_option(term.buffer, 'modifiable', false)
        end

        if term.on_exit then
          term.on_exit(code, term)
        end

        if term.close_on_exit then
          local delay = term.close_immediately and 100 or term.close_delay
          vim.defer_fn(function()
            term.close()
          end, delay)
        end
      end
    })

    vim.cmd("startinsert")

    return term.job_id and term.job_id > 0
  end

  term.stop = function()
    if term.job_id and term.job_id > 0 then
      vim.fn.jobstop(term.job_id)
      term.job_id = nil
      return true
    end
    return false
  end

  term.close = function()
    if term.stop() then
      vim.defer_fn(function()
        if term.buffer and vim.api.nvim_buf_is_valid(term.buffer) then
          vim.api.nvim_buf_delete(term.buffer, { force = true })
          term.buffer = nil
          term.window = nil
          M.active_terminals[term.id] = nil
        end
      end, 100)
      return true
    elseif term.buffer and vim.api.nvim_buf_is_valid(term.buffer) then
      vim.api.nvim_buf_delete(term.buffer, { force = true })
      term.buffer = nil
      term.window = nil
      M.active_terminals[term.id] = nil
      return true
    end
    return false
  end

  term.get_output = function()
    return table.concat(term.output_lines, "\n")
  end

  term.focus = function()
    if term.window and vim.api.nvim_win_is_valid(term.window) then
      vim.api.nvim_set_current_win(term.window)
      vim.cmd("startinsert")
      return true
    elseif term.buffer and vim.api.nvim_buf_is_valid(term.buffer) then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == term.buffer then
          vim.api.nvim_set_current_win(win)
          vim.cmd("startinsert")
          return true
        end
      end

      return term.open()
    end
    return false
  end

  return term
end

function M.open_term_command(cmd, opts)
  opts = opts or {}
  opts.command = cmd

  local term = M.new_terminal(opts)
  term.open(opts.direction, opts.size)
  term.start()

  return term
end

function M.get_terminal(id)
  return M.active_terminals[id]
end

return M

