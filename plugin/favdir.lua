-- Plugin loader for nvim-favdir

if vim.g.loaded_favdir then
  return
end
vim.g.loaded_favdir = true

-- Create user commands
vim.api.nvim_create_user_command('FavdirOpen', function()
  require('favdir').show()
end, { desc = 'Open favorite directories UI' })

vim.api.nvim_create_user_command('FavdirToggle', function()
  require('favdir').toggle()
end, { desc = 'Toggle favorite directories UI' })

vim.api.nvim_create_user_command('FavdirAddDir', function()
  require('favdir').add_cwd()
end, { desc = 'Add current directory to favorites' })

vim.api.nvim_create_user_command('FavdirAddFile', function()
  require('favdir').add_file()
end, { desc = 'Add current file to favorites' })
