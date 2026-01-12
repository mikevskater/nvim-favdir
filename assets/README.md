# Assets

This directory contains VHS tape files for generating demo GIFs.

## Prerequisites

Install [VHS](https://github.com/charmbracelet/vhs):

```bash
# macOS
brew install vhs

# Windows (scoop)
scoop install vhs

# Windows (chocolatey)
choco install vhs

# Linux
# See https://github.com/charmbracelet/vhs#installation
```

## Generating GIFs

```bash
cd assets

# Generate main demo
vhs demo.tape

# Generate all demos
vhs demo.tape
vhs groups.tape
vhs sorting.tape
```

## Tape Files

| File | Output | Description |
|:-----|:-------|:------------|
| `demo.tape` | `demo.gif` | Main demo for README (open UI, create group, add items) |
| `groups.tape` | `groups.gif` | Group management (nested groups, rename) |
| `sorting.tape` | `sorting.gif` | Sorting features (sort modes, reordering) |

## Notes

- Tapes assume `pwsh` (PowerShell) shell on Windows. Change `Set Shell` for other platforms.
- Theme is set to "Catppuccin Mocha". Available themes: https://github.com/charmbracelet/vhs#themes
- You may need to adjust the tape scripts if your plugin is not loaded or configured differently.
- For best results, ensure nvim-favdir is installed and working before recording.

## Customizing

Edit the `.tape` files to:
- Change terminal size: `Set Width` / `Set Height`
- Change font size: `Set FontSize`
- Change theme: `Set Theme "Theme Name"`
- Adjust timing: `Sleep Xs` commands
