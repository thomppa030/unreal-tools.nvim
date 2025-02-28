local M = {}
local lsp = require('unreal-tools.lsp')
local build = require('unreal-tools.buildproject')

function M.setup(config, project)
  -- Don't proceed if commands are disabled in config
  if not config.commands.enable then
    return
  end

  vim.api.nvim_create_user_command("UEDiagnosis", function()
    require('unreal-tools').diagnose()
  end, {
    desc = "Shows Plugin Diagnosis"
  })

  vim.api.nvim_create_user_command("UEGenerateCompileCommands", function()
    lsp.generate_compile_commands(config, project)
  end, {
    desc = "Generate compile_commands.json for Unreal Engine projects"
  })

  -- Command to switch between header and source file
  vim.api.nvim_create_user_command("UESwitchHeaderSource", function()
    local current_file = vim.fn.expand(':t')
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

    -- Try to find the file useing fd if available
    local fd_cmd = "fd " .. target_file .. " " .. project.source_dir
    local handle = io.popen(fd_cmd)

    if handle then
      local result = handle:read("*a")
      handle:close()

      if result and result ~= "" then
        local found_file = result:match("([^\n]+)")
        if found_file then
          vim.cmd("edit" .. found_file)
          return
        end
      end
    end

    -- Fallback to recursive find
    local find_cmd = "find " .. project.source_dir .. " -name" .. target_file
    handle = io.popen(find_cmd)

    if handle then
      local result = handle:read("*a")
      handle:close()

      if result and result ~= "" then
        local found_file = result:match("([^\n]+)")
        if found_file then
          vim.cmd("edit" .. found_file)
          return
        end
      end
    end

    vim.notify("Could not find matching file: " .. target_file, vim.log.levels.WARN)
  end, {
      desc = "Switch between header and source file for UE"
    })

  vim.api.nvim_create_user_command("UEOpenSourceDir", function ()
    vim.cmd("edit " .. project.source_dir)
  end, {
    desc = "Open UE project Source directory"
  })

  vim.api.nvim_create_user_command("UEOpenContentDir", function ()
    vim.cmd("edit " .. project.source_dir)
  end, {
    desc = "Open UE project Content directory"
  })

  vim.api.nvim_create_user_command("UEBuildEditor", function()
    build.build_editor(config, project)
  end, {
      desc = "Build the Unreal Editor target in a terminal Buffer"
    })

  vim.api.nvim_create_user_command("UERunProject", function()
    build.start_editor(config, project)
  end, {
      desc = "Runs the Unreal Editor target in a terminal Buffer"
    })

  vim.api.nvim_create_user_command("UEBuildAndRunProject", function()
    build.build_and_start_editor(config, project)
  end, {
      desc = "Builds and Runs the Unreal Editor Target"
    })
end


return M
