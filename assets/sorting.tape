# VHS Tape: nvim-favdir Sorting Features
# Run: vhs sorting.tape
# Output: sorting.gif

Output sorting.gif

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
Hide
Type "nvim"
Enter
Sleep 5s

Show
# Open favdir UI with existing saved data
Type ":FavdirOpen"
Enter
Sleep 800ms

# Select a group with items
Type "j"
Enter
Sleep 500ms

# Switch to right panel where items are
Tab
Sleep 500ms

# Cycle through sort modes
Type "s"
Sleep 600ms

# Show "name" sort
Sleep 400ms
Type "s"
Sleep 600ms

# Show "type" sort
Sleep 400ms
Type "s"
Sleep 600ms

# Show "modified" sort
Sleep 400ms

# Toggle sort order (descending)
Type "S"
Sleep 600ms

# Show descending order
Sleep 400ms

# Toggle back to ascending
Type "S"
Sleep 600ms

# Manual reorder - move item up
Ctrl+k
Sleep 400ms
Ctrl+k
Sleep 400ms

# Move item down
Ctrl+j
Sleep 400ms

# Show final state
Sleep 600ms

# Close
Type "q"
Sleep 300ms

# Quit
Type ":qa!"
Enter
Sleep 300ms
