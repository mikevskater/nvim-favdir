---@class FavdirModule
---Favorite directories plugin for Neovim
---Two-panel UI for managing groups and favorite directories/files
---@module favdir

local M = {}

M.version = "0.6.0"

-- Lazy-loaded modules
local _state = nil
local _ui = nil
local _initialized = false

---Get the state module (lazy-loaded)
---@return FavdirState
local function get_state()
  if not _state then
    _state = require("favdir.state")
  end
  return _state
end

---Get the UI module (lazy-loaded)
---@return FavdirUI
local function get_ui()
  if not _ui then
    _ui = require("favdir.ui")
  end
  return _ui
end

---@class FavdirConfig
---@field data_file string Path to data file
---@field ui_state_file string Path to UI state file
---@field window_height_ratio number Height ratio (0-1)
---@field window_width_ratio number Width ratio (0-1)
---@field left_panel_width_ratio number Left panel width ratio (0-1)
---@field confirm_deletions boolean Confirm before deleting
---@field default_groups string[] Default groups on first run
---@field protected_groups string[] Groups that cannot be deleted
---@field use_nerd_font boolean|nil Use Nerd Font icons (nil = auto-detect)

---Detect if Nerd Fonts are likely available
---@return boolean
local function detect_nerd_font()
  -- Check common indicators of Nerd Font usage:

  -- 1. User explicitly set vim.g.have_nerd_font (used by kickstart.nvim and many configs)
  if vim.g.have_nerd_font == true then
    return true
  end
  if vim.g.have_nerd_font == false then
    return false
  end

  -- 2. Check if nvim-web-devicons is available (implies Nerd Font usage)
  local has_devicons = pcall(require, "nvim-web-devicons")
  if has_devicons then
    return true
  end

  -- 3. Check if mini.icons is available
  local has_mini_icons = pcall(require, "mini.icons")
  if has_mini_icons then
    return true
  end

  -- 4. Check for common Nerd Font terminal environment hints
  local term = vim.env.TERM_PROGRAM or ""
  local nerd_font_terminals = {
    "WezTerm", "Alacritty", "kitty", "iTerm.app"
  }
  for _, t in ipairs(nerd_font_terminals) do
    if term:find(t, 1, true) then
      return true
    end
  end

  -- Default to false if we can't detect
  return false
end

---@type FavdirConfig
M.config = {
  data_file = vim.fn.stdpath('data') .. '/favdirs.json',
  ui_state_file = vim.fn.stdpath('data') .. '/favdirs_ui_state.json',
  window_height_ratio = 0.7,
  window_width_ratio = 0.8,
  left_panel_width_ratio = 0.35,
  confirm_deletions = true,
  default_groups = {},  -- No default groups, user manages all
  protected_groups = {},  -- No protected groups
  use_nerd_font = nil, -- nil = auto-detect
}

---Ensure the plugin is initialized (called automatically on first use)
---@return boolean success
local function ensure_initialized()
  if _initialized then
    return true
  end

  -- Auto-detect Nerd Font if not explicitly set
  if M.config.use_nerd_font == nil then
    M.config.use_nerd_font = detect_nerd_font()
  end

  -- Ensure nvim-float is available
  local ok, nf = pcall(require, "nvim-float")
  if not ok then
    vim.notify("nvim-favdir: nvim-float is required but not installed", vim.log.levels.ERROR)
    return false
  end

  -- Setup nvim-float if not already done
  nf.setup()

  -- Initialize state module with config
  get_state().init(M.config)

  _initialized = true
  return true
end

---Setup the plugin with user configuration
---@param opts FavdirConfig? User configuration options
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- Reset initialized flag to re-apply config
  _initialized = false

  -- Initialize with new config
  ensure_initialized()
end

---Show the favorites UI
function M.show_ui()
  if not ensure_initialized() then return end
  get_ui().show(M.config)
end

---Toggle the favorites UI (show if hidden, hide if shown)
function M.toggle_ui()
  if not ensure_initialized() then return end
  get_ui().toggle(M.config)
end

---Add the current working directory to favorites
---@param group_path string? Optional group path (prompts if not provided)
function M.add_current_dir(group_path)
  if not ensure_initialized() then return end
  local cwd = vim.fn.getcwd()
  if group_path then
    get_state().add_item(group_path, cwd)
  else
    -- Show group picker
    get_ui().pick_group_and_add_item(M.config, cwd)
  end
end

---Add the current buffer's file to favorites
---@param group_path string? Optional group path (prompts if not provided)
function M.add_current_file(group_path)
  if not ensure_initialized() then return end
  local file = vim.fn.expand('%:p')
  if file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end
  if group_path then
    get_state().add_item(group_path, file)
  else
    -- Show group picker
    get_ui().pick_group_and_add_item(M.config, file)
  end
end

---Get all data (for external access)
---@return FavdirData
function M.get_data()
  if not ensure_initialized() then return { groups = {} } end
  return get_state().load_data()
end

---Get all groups as flat list (for completion, etc.)
---@return string[] List of group paths
function M.get_group_list()
  if not ensure_initialized() then return {} end
  return get_state().get_group_list()
end

return M
