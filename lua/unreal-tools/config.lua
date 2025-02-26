local M = {}

M.defaults = {
  ue_paths = {
    os.getenv("HOME") .. "/UnrealEngine",
    "/opt/UnrealEngine",
  },

  ue_version = nil, -- e.g. "5.5" or nil to autodetect

  lsp = {
    enable = true,
    clangd_args = {
      "--background-index",
      "--clang-tidy",
      "--header-insertion=never",
      "--completion-style=detailed",
      "--function-arg-placeholders",
      "--fallback-style=llvm",
      "--limit-results=500",
      "--limit-references=1000",
    },
    auto_generate_compile_commands = true,
  },

  telescope = {
    enable = true,
    ignored_patterns = {
      "%.generated%.h",
      "Intermediate/",
      "Saved/",
      "DerivedDataCache/",
      "Build/",
      "Binaries/",
      "%.o$",
      "%.obj$",
      "%.a$",
      "%.lib$",
      "%.so$",
      "%.dll$",
      "%.dylib$",
      "%.png$",
      "%.jpg$",
      "%.uasset$",
      "%.umap$",
    },
  },

  snippets = {
    enable = true,
  },

  commands = {
    enable = true,
  },

  use_keymaps = true,

  keymap_prefix = "<leader>u",

  notify_non_ue_project = false
}

return M
