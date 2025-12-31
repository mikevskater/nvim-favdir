---@class FavdirModule
---Favorite directories plugin for Neovim
---Two-panel UI for managing groups and favorite directories/files
---@module favdir

local M = {}

M.version = "0.1.0"

-- Lazy-loaded modules
local _state = nil
local _ui = nil

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

---@type FavdirConfig
M.config = {
  data_file = vim.fn.stdpath('data') .. '/favdirs.json',
  ui_state_file = vim.fn.stdpath('data') .. '/favdirs_ui_state.json',
  window_height_ratio = 0.7,
  window_width_ratio = 0.8,
  left_panel_width_ratio = 0.35,
  confirm_deletions = true,
  default_groups = { "Work", "Personal", "Projects" },
  protected_groups = { "Uncategorized" },
}

---Setup the plugin with user configuration
---@param opts FavdirConfig? User configuration options
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- Ensure nvim-float is available
  local ok, nf = pcall(require, "nvim-float")
  if not ok then
    vim.notify("nvim-favdir: nvim-float is required but not installed", vim.log.levels.ERROR)
    return
  end

  -- Setup nvim-float if not already done
  nf.setup()

  -- Initialize state module with config
  get_state().init(M.config)
end

---Show the favorites UI
function M.show_ui()
  get_ui().show(M.config)
end

---Toggle the favorites UI (show if hidden, hide if shown)
function M.toggle_ui()
  get_ui().toggle(M.config)
end

---Add the current working directory to favorites
---@param group_path string? Optional group path (prompts if not provided)
function M.add_current_dir(group_path)
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
  return get_state().load_data()
end

---Get all groups as flat list (for completion, etc.)
---@return string[] List of group paths
function M.get_group_list()
  return get_state().get_group_list()
end

return M
