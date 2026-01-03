---@class FavdirModule
---Favorite directories plugin for Neovim
---Two-panel UI for managing groups and favorite directories/files
---@module favdir

local M = {}

M.version = "0.9.0"

local state = require("favdir.state")
local ui = require("favdir.ui")

---@class FavdirConfig
---@field data_file string Path to data file
---@field ui_state_file string Path to UI state file
---@field window_height_ratio number Height ratio (0-1)
---@field window_width_ratio number Width ratio (0-1)
---@field left_panel_width_ratio number Left panel width ratio (0-1)
---@field default_groups string[] Default groups on first run
---@field protected_groups string[] Groups that cannot be deleted/moved
---@field use_nerd_font boolean Use Nerd Font icons

---@type FavdirConfig
M.config = {
  data_file = vim.fn.stdpath('data') .. '/favdirs.json',
  ui_state_file = vim.fn.stdpath('data') .. '/favdirs_ui_state.json',
  window_height_ratio = 0.7,
  window_width_ratio = 0.8,
  left_panel_width_ratio = 0.35,
  default_groups = {},
  protected_groups = {},
  use_nerd_font = true,
}

local initialized = false

---Detect if Nerd Fonts are likely available
---@return boolean
local function detect_nerd_font()
  -- User explicitly set vim.g.have_nerd_font
  if vim.g.have_nerd_font == true then return true end
  if vim.g.have_nerd_font == false then return false end

  -- Check if nvim-web-devicons is available (implies Nerd Font usage)
  if pcall(require, "nvim-web-devicons") then return true end

  -- Check if mini.icons is available
  if pcall(require, "mini.icons") then return true end

  -- Check for common Nerd Font terminal environment hints
  local term = vim.env.TERM_PROGRAM or ""
  local nerd_font_terminals = { "WezTerm", "Alacritty", "kitty", "iTerm.app" }
  for _, t in ipairs(nerd_font_terminals) do
    if term:find(t, 1, true) then return true end
  end

  return false
end

---Initialize the plugin
local function init()
  if initialized then return end

  -- Auto-detect Nerd Font if using default
  if M.config.use_nerd_font == true and not vim.g.have_nerd_font then
    M.config.use_nerd_font = detect_nerd_font()
  end

  -- Setup nvim-float
  require("nvim-float").setup()

  -- Initialize state with config
  state.init(M.config)

  initialized = true
end

---Setup the plugin with user configuration
---@param opts FavdirConfig? User configuration options
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  initialized = false
  init()
end

---Show the favorites UI
function M.show()
  init()
  ui.show(M.config)
end

---Toggle the favorites UI
function M.toggle()
  init()
  ui.toggle(M.config)
end

---Add the current working directory to favorites
---@param group_path string? Optional group path (prompts if not provided)
function M.add_cwd(group_path)
  init()
  local cwd = vim.fn.getcwd()
  if group_path then
    state.add_item(group_path, cwd)
  else
    ui.pick_group_and_add_item(cwd)
  end
end

---Add the current buffer's file to favorites
---@param group_path string? Optional group path (prompts if not provided)
function M.add_file(group_path)
  init()
  local file = vim.fn.expand('%:p')
  if file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end
  if group_path then
    state.add_item(group_path, file)
  else
    ui.pick_group_and_add_item(file)
  end
end

---Get all data (for external access)
---@return FavdirData
function M.get_data()
  init()
  return state.load_data()
end

---Get all groups as flat list
---@return string[]
function M.get_groups()
  init()
  return state.get_group_list()
end

return M
