# VHS Tape: nvim-favdir Group Management
# Run: vhs groups.tape
# Output: groups.gif

Output groups.gif

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

# Start Neovim
Type "nvim"
Enter
Sleep 5s

Show
# Open favdir UI in sandbox mode (clean state, no persistence)
Type ":FavdirSandbox"
Enter
Sleep 800ms

# Create first group "Work"
Type "a"
Sleep 400ms
Enter
Sleep 300ms

# Edit the input field, type name, save, apply
Enter
Sleep 100ms
Type "Work"
Enter
Sleep 100ms
Type "s"
Sleep 600ms

# Create nested group "Work.Active"
Type "a"
Sleep 400ms
Enter
Sleep 300ms

# Edit the input field, type name, save, apply
Enter
Sleep 100ms
Type "Active"
Enter
Sleep 100ms
Type "s"
Sleep 600ms

# Create another nested group "Work.Archive"
Type "a"
Sleep 400ms
Enter
Sleep 300ms

# Edit the input field, type name, save, apply
Enter
Sleep 100ms
Type "Archive"
Enter
Sleep 100ms
Type "s"
Sleep 600ms

# Collapse Work group
Type "o"
Sleep 300ms

# Expand Work group to show children
Type "o"
Sleep 600ms

# Show the nested structure
Sleep 800ms

# Navigate to Active child
Type "j"
Sleep 300ms

# Rename it - press r
Type "r"
Sleep 400ms

# Edit the input field
Enter
Sleep 100ms

# Clear existing name and type new name
Backspace 6
Type "Current"
Enter
Sleep 100ms
Type "s"
Sleep 600ms

# Show the renamed group
Sleep 800ms

# Close
Type "q"
Sleep 300ms

# Quit
Type ":qa!"
Enter
Sleep 300ms
