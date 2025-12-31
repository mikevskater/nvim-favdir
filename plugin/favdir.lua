-- Plugin loader for nvim-favdir
-- This file is automatically loaded by Neovim

if vim.g.loaded_favdir then
  return
end
vim.g.loaded_favdir = true

-- Create user commands
vim.api.nvim_create_user_command('FavdirOpen', function()
  require('favdir').show_ui()
end, { desc = 'Open favorite directories UI' })

vim.api.nvim_create_user_command('FavdirToggle', function()
  require('favdir').toggle_ui()
end, { desc = 'Toggle favorite directories UI' })

vim.api.nvim_create_user_command('FavdirAddDir', function()
  require('favdir').add_current_dir()
end, { desc = 'Add current directory to favorites' })

vim.api.nvim_create_user_command('FavdirAddFile', function()
  require('favdir').add_current_file()
end, { desc = 'Add current file to favorites' })
