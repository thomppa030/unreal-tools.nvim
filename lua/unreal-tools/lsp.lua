local M = {}
local utils = require('nvim-unreal.utils')
local detection = require('nvim-unreal.detection')

function M.setup(config, project)
  if not config.lsp.enable then
    return
  end

  local has_lspconfig, lspconfig = pcall(require, "lspconfig")
  if not has_lspconfig then
    vim.notify("Unreal-Tools: nvim-lspconfig not found, LSP features disabled", vim.log.levels.WARN)
    return
  end

  local compile_commands_paths = {
    project.path .. "/.vscode/compile_commands.json",
    project.path .. "/compile_commands.json",
  }

  local compile_commands_dir = nil

  for _, path in ipairs(compile_commands_paths) do
    if utils.file_exists(path) then
      compile_commands_dir = vim.fn.fnamemodify(path, ":h")
      break
    end
  end

  if not compile_commands_dir and config.lsp.auto_generate_compile_commands then
    M.generate_compile_commands(config, project)

    -- Assume it will be created in the project root
    compile_commands_dir = project.path
  end

  local clangd_capabilities = vim.lsp.protocol.make_client_capabilities()

  local has_cmp_lsp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if has_cmp_lsp then
    clangd_capabilities = cmp_lsp.default_capabilities(clangd_capabilities)
  end

  local clangd_cmd = { "clangd" }

  for _, arg in ipairs(config.lsp.clangd_args) do
    table.insert(clangd_cmd, arg)
  end

  lspconfig.clangd.setup({
    cmd = clangd_cmd,
    capabilities = clangd_capabilities,
    on_attach = function(client, bufnr)
      M.on_attach(client, bufnr, config, project)
    end,
    root_dir = function()
      return project.path
    end,
  })

  vim.api.nvim_create_autocmd("Filetype", {
    pattern = { "cpp", "h", "hpp" },
    callback = function()
      vim.bo.tabstop = 4
      vim.bo.shiftwidth = 4
      vim.bo.expandtab = true

      vim.bo.commentstring = "// %s"
    end
  })
end

function M.on_attach(client, bufnr, config, project)
  vim.cmd([[
    syntax keyword ueKeyword UCLASS UPROPERTY UFUNCTION USTRUCT UENUM UMETA
      highlight link ueKeyword Statement
  ]])
end

function M.generate_compile_commands(config, project)
  local engine_path = detection.find_engine_path(config)
  if not engine_path then
    vim.notify("Unreal-Tools: Cannot generate compile_commands.json - UE Engine path not found", vim.log.levels.ERROR)
    return false
  end

  local project_name = project.name

  local script_path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ":h:h:h:h") ..
      "scripts/generate_compile_commands.sh"

  if not utils.file_exists(script_path) then
    vim.notify("Unreal-Tools: compile_commands.sh script not found at " .. script_path,
      vim.log.levels.ERROR)
    return false
  end

  os.execute("chmod +x " .. script_path)

  local cmd = script_path .. " " ..
      "\"" .. engine_path .. "\" " ..
      "\"" .. project.path .. "\" " ..
      "\"" .. project_name .. "\""

  vim.notify("Unreal-Tools: Generating compile_commands.json...", vim.log.levels.INFO)

  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("Unreal-Tools: compile_commands.json generated successfully", vim.log.levels.INFO)

        vim.cmd("LspRestart")
      else
        vim.notify("Unreal-Tools: Failed to generate compile_commands.json", vim.log.levels.ERROR)
      end
    end,
    stdout_buffered = true,
    on_stdout = function (_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            vim.notify("Unreal-Tools: " .. line, vim.log.levels.INFO)
          end
        end
      end
    end,
    stderr_buffered = true,
    on_stderr = function (_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            vim.notify("Unreal-Tools: " .. line, vim.log.levels.INFO)
          end
        end
      end
    end,
  })

  return true
end

return M
