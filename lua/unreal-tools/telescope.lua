local M = {}

function M.setup(config, project)
  if not config.telescope.enable then
    return
  end

  local has_telescope, telescope = pcall(require, "telescope")
  if not has_telescope then
    vim.notify("Unreal-Tools: telescope not found, Telescope features disabled", vim.log.levels.WARN)
    return
  end

  telescope.setup({
    defaults = vim.tbl_extend("force", telescope.defaults or {}, {
      file_ignore_patterns = config.telescope.ignored_patterns,
    }),
    pickers = {
      find_files = {
        hidden = false,
        follow = true,
      },
      live_grep = {
        additional_args = function()
          return { "--glob", "!*{.generated.h}" }
        end,
      },
    },
  })

  M.register_pickers(config, project)
end

function M.register_pickers(config, project)
  local has_telescope_builtin, builtin = pcall(require, "telescope.builtin")
  if not has_telescope_builtin then
    return
  end

  local function make_ue_picker(opts)
    return function()
      builtin[opts.picker]({
        prompt_title = opts.title,
        cwd = opts.cwd or project.path,
        file_ignore_patterns = opts.ignored_patterns or config.telescope.ignored_patterns,
        additional_arg = opts.additional_args,
        default_text = opts.default_text,
      })
    end
  end

  local prefix = config.keymap_prefix

  M.find_source_files = make_ue_picker({
    picker = "find_files",
    title = "UE Source Files",
    cwd = project.source_dir,
    ignored_patterns = vim.list_extend(
      vim.deepcopy(config.telescope.ignored_patterns),
      { "*.generated.h" }
    ),
  })
  vim.keymap.set('n', prefix .. "ff", M.find_source_files, { desc = "Find UE source files" })

  M.grep_source = make_ue_picker({
    picker = "live_grep",
    title = "Grep UE Source",
    cwd = project.source_dir,
    additional_args = function()
      return { "--glob", "!*{generated.h}" }
    end,
  })
  vim.keymap.set('n', prefix .. "fg", M.grep_source, { desc = "Grep UE source" })

  M.find_classes = make_ue_picker({
    picker = "find_files",
    title = "UE Classes",
    cwd = project.source_dir,
    default_text = ".h",
    ignored_patterns = vim.list_extend(
      vim.deepcopy(config.telescope.ignored_patterns),
      { "*.generated.h" }
    ),
  })
  vim.keymap.set('n', prefix .. "fc", M.find_classes, { desc = "Find UE Classes" })

  M.find_header_source = function()
    local current_file = vim.fn.expand('%:t')
    local target_ext
    local current_ext = vim.fn.expand('%:e')

    if current_ext == 'cpp' then
      target_ext = 'h'
    elseif current_ext == 'h' then
      target_ext = 'cpp'
    else
      vim.notify("Not a .cpp or .h file", vim.log.levels.ERROR)
      return
    end

    local base_name = vim.fn.expand('%:t:r')
    local target_file = base_name .. "." .. target_ext

    builtin.find_files({
      prompt_title = "Find " .. target_file,
      default_text = target_file,
      cwd = project.source_dir,
    })
  end
  vim.keymap.set('n', prefix .. "fs", M.find_header_source, { desc = "Find corresponding header/source" })
end

return M
