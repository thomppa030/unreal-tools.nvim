# EditAnywhere for Neovim

A comprehensive Unreal Engine development environment for Neovim.

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![Neovim Version](https://img.shields.io/badge/Neovim-%3E%3D0.10.0-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Using lazy.nvim](#using-lazynvim)
  - [Using packer.nvim](#using-packernvim)
- [Configuration](#configuration)
  - [Default Configuration](#default-configuration)
  - [Configuration Options](#configuration-options)
- [Commands](#commands)
- [Default Keymaps](#default-keymaps)
- [Debugging](#debugging)
- [Reloading the Plugin](#reloading-the-plugin)
- [Project Detection](#project-detection)
- [Engine Path Detection](#engine-path-detection)
- [Contributing](#contributing)
- [License](#license)

## Overview

Unreal Tools provides Unreal Engine development capabilities within Neovim. It includes project detection, LSP integration, build utilities, and navigation features **currently only on Linux**.

## Features

- **Automatic Project Detection**: Automatically detects Unreal Engine projects and configures your environment
- **LSP Integration**: Seamless clangd integration with UE-specific configurations
- **Build Tools**: Build and run your UE project directly from Neovim
- **Telescope Integration**: Find and navigate UE project files efficiently

## Requirements

- Neovim >= 0.10.0
- Unreal Engine (Linux)
- Required Dependencies:
  - lspconfig
- Optional Dependencies:
  - telescope.nvim
  - plenary.nvim
- `clangd` for LSP support

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/unreal-tools",
  dependencies = {
    "neovim/nvim-lspconfig",
    "nvim-telescope/telescope.nvim",  -- optional but recommended
    "nvim-lua/plenary.nvim",          -- required by telescope
  },
  config = function()
    require("unreal-tools").setup({
      -- your configuration here (see Configuration section)
    })
  end,
  ft = { "cpp", "h", "hpp" }
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/unreal-tools",
  requires = {
    "neovim/nvim-lspconfig",
    "nvim-telescope/telescope.nvim",  -- optional but recommended
    "nvim-lua/plenary.nvim",          -- required by telescope
  },
  config = function()
    require("unreal-tools").setup({
      -- your configuration here (see Configuration section)
    })
  end
}
```

## Configuration

Unreal Tools comes with sensible defaults, but you can customize it to match your workflow.

### Default Configuration

```lua
local unreal_tools = require('unreal-tools').setup({
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
})
```

### Configuration Options

| Option | Description |
|--------|-------------|
| `ue_paths` | List of directories to search for Unreal Engine installations |
| `ue_version` | Specific UE version to use (e.g., "5.5"), or `nil` to autodetect |
| `lsp.enable` | Enable LSP integration |
| `lsp.clangd_args` | Arguments to pass to clangd |
| `lsp.auto_generate_compile_commands` | Automatically generate compile_commands.json if missing |
| `telescope.enable` | Enable Telescope integration |
| `telescope.ignored_patterns` | File patterns to ignore in Telescope |
| `snippets.enable` | Enable UE-specific snippets |
| `commands.enable` | Enable UE-specific commands |
| `use_keymaps` | Enable default keymaps |
| `keymap_prefix` | Prefix for UE-specific keymaps |
| `notify_non_ue_project` | Show notification when not in a UE project |

## Commands

Unreal Tools provides several user commands to enhance your UE development workflow:

| Command | Description |
|---------|-------------|
| `UEGenerateCompileCommands` | Generate compile_commands.json for clangd |
| `UESwitchHeaderSource` | Switch between header (.h) and source (.cpp) files |
| `UEOpenSourceDir` | Open the project's Source directory |
| `UEOpenContentDir` | Open the project's Content directory |
| `UEBuildEditor` | Build the Unreal Editor target |
| `UERunProject` | Run the Unreal Editor |
| `UEBuildAndRunProject` | Build and run the Unreal Editor |
| `UEDiagnose` | Display diagnostic information about the plugin setup |

## Default Keymaps

Unreal Tools provides sensible default keymaps (with `<leader>u` prefix by default):

| Keymap | Command | Description |
|--------|---------|-------------|
| `<leader>uos` | `UEOpenSourceDir` | Open Source directory |
| `<leader>uoc` | `UEOpenContentDir` | Open Content directory |
| `<leader>ugc` | `UEGenerateCompileCommands` | Generate compile_commands.json |
| `<leader>uhs` | `UESwitchHeaderSource` | Switch between header/source files |
| `<leader>uff` | Telescope integration | Find UE source files |
| `<leader>ufg` | Telescope integration | Grep UE source |
| `<leader>ufc` | Telescope integration | Find UE classes |
| `<leader>ufs` | Telescope integration | Find corresponding header/source |

Additionally, standard LSP keymaps are set up:

| Keymap | Function | Description |
|--------|----------|-------------|
| `gD` | `vim.lsp.buf.declaration` | Go to declaration |
| `gd` | `vim.lsp.buf.definition` | Go to definition |
| `K` | `vim.lsp.buf.hover` | Show hover information |
| `gi` | `vim.lsp.buf.implementation` | Go to implementation |
| `<C-k>` | `vim.lsp.buf.signature_help` | Show signature help |
| `<leader>rn` | `vim.lsp.buf.rename` | Rename symbol |
| `<leader>ca` | `vim.lsp.buf.code_action` | Code action |
| `gr` | `vim.lsp.buf.references` | Find references |
| `<leader>-` | `:b#<CR>` | Switch to last buffer |

## Debugging

If you encounter issues, you can use the built-in diagnostic command:

```
:UEDiagnose
```

Or call the diagnostic function directly:

```lua
:lua require('unreal-tools').diagnose()
```

This will open a buffer with detailed information about your Unreal Tools setup, including:
- Neovim version
- Plugin initialization status
- Dependencies
- Project information
- Configuration details

## Reloading the Plugin

If you need to reload the plugin after making configuration changes:

```lua
:lua require('unreal-tools').reload()
```

## Project Detection

Unreal Tools detects UE projects using several methods:
1. Presence of a `.uproject` file with matching project name
2. Any `.uproject` file in the current directory
3. Presence of both `Source` and `Content` directories
4. Presence of `.Build.cs` files in the Source directory

## Engine Path Detection

The plugin attempts to find your Unreal Engine installation using:
1. Engine specified in the `.uproject` file
2. Parent directories (for source builds)
3. Epic Games launcher installation registry
4. Common installation paths
5. Custom paths specified in your configuration

## Contributing

This project is currently in early development, and I am focusing on establishing core functionality and architecture. While I appreciate interest in the project, I am not actively seeking code contributions at this time.
However, I do welcome:

- Bug reports and detailed feature requests through GitHub issues
- Documentation improvements
- Testing on different Unreal Engine versions and configurations

Once the plugin reaches a more stable state, I plan to open up for broader community contributions. Feel free to star and watch the repository for updates on when that happens.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
