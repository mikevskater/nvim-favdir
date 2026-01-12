# VHS Tape: nvim-favdir Main Demo
# Run: vhs demo.tape
# Output: demo.gif

Output demo.gif

Hide
# Terminal settings
Set Shell "cmd"
Set FontSize 14
Set Width 1200
Set Height 700
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful
Set Padding 2
Set FontFamily "JetBrainsMono Nerd Font Mono"

# Start Neovim with a sample project
Type "nvim"
Enter 1
Sleep 5s

Show
# Open favdir UI in sandbox mode (clean state, no persistence)
Type ":FavdirSandbox"
Enter 1
Sleep 1s

# Show the two-panel UI - left panel is focused
Sleep 500ms

# Create a new group
Type "a"
Sleep 500ms
Enter 1
Sleep 500ms

# Type group name
Enter 1
Sleep 100ms
Type "Projects"
Enter 1
Sleep 100ms
Type "s"
Sleep 800ms

# Expand the group (select it)
Type "j"
Sleep 300ms
Enter
Sleep 500ms

# Switch to right panel
Tab
Sleep 500ms

# Add current directory
Type "a"
Sleep 500ms

# Select "Current Directory"
Enter 1
Sleep 800ms

# Show the item was added
Sleep 500ms

# Navigate into the item
Type "o"
Sleep 300ms

# Open a (cd into it)
Type "jj"
Sleep 75ms
Enter 1
Sleep 800ms

# Show we're back in Neovim
Sleep 1s

Hide
# Quit Neovim
Type ":qa!"
Enter 1
