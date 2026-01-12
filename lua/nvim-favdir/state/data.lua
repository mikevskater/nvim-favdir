---@module favdir.state.data
---Data persistence for favdir - handles loading and saving data files

local M = {}

local logger = require("nvim-favdir.logger")
local constants = require("nvim-favdir.constants")

-- ============================================================================
-- Data Structures (Type Definitions)
-- ============================================================================

---@class FavdirItem
---@field path string Absolute path to file or directory
---@field type "dir"|"file" Item type
---@field order number Sort order within group

---@class FavdirDirLink
---@field name string Display name in left panel
---@field path string Absolute directory path
---@field order number Sort order (shared with children groups)

---@class FavdirGroup
---@field name string Group name
---@field items FavdirItem[] Files and directories in this group
---@field order number Sort order
---@field children FavdirGroup[]? Child groups (for hierarchy)
---@field dir_links FavdirDirLink[]? Directory links (shown in left panel, load filesystem in right)

---@class FavdirData
---@field groups FavdirGroup[] Top-level groups

---@class FavdirUIState
---@field expanded_groups string[] List of expanded group paths (e.g., "Work.Projects")
---@field last_selected_group string? Last selected group path
---@field last_selected_type "group"|"dir_link"? Type of last selected item
---@field last_selected_dir_link string? Base path of selected dir_link's directory
---@field dir_link_current_path string? Current browsing path within dir_link (for navigation)
---@field is_browsing_directory boolean? Whether we're in directory browse mode
---@field browse_base_path string? Base path for directory browsing (can't go above this)
---@field browse_current_path string? Current path when browsing a directory
---@field focused_panel "left"|"right" Currently focused panel
---@field left_cursor {row: number, col: number} Left panel cursor position
---@field right_cursor {row: number, col: number} Right panel cursor position
---@field left_sort_mode "custom"|"alpha" Left panel sort mode
---@field right_sort_mode "custom"|"name"|"created"|"modified"|"size"|"type" Right panel sort mode
---@field dir_sort_mode "name"|"created"|"modified"|"size"|"type" Directory view sort mode
---@field left_sort_asc boolean Left panel sort ascending (true) or descending (false)
---@field right_sort_asc boolean Right panel sort ascending
---@field dir_sort_asc boolean Directory view sort ascending

-- ============================================================================
-- Module State
-- ============================================================================

---@type FavdirConfig?
local config = nil

---@type boolean
local sandbox_mode = false

---@type FavdirData?
local sandbox_data = nil

---@type FavdirUIState?
local sandbox_ui_state = nil

---Initialize the data module with config
---@param cfg FavdirConfig
function M.init(cfg)
  config = cfg
end

---Get the current config
---@return FavdirConfig?
function M.get_config()
  return config
end

---Enable sandbox mode (no persistence, clean state)
---@param initial_data FavdirData? Optional initial data for sandbox
---@param initial_ui_state FavdirUIState? Optional initial UI state
function M.enable_sandbox(initial_data, initial_ui_state)
  sandbox_mode = true
  sandbox_data = initial_data or { groups = {} }
  sandbox_ui_state = initial_ui_state
  logger.debug("Sandbox mode enabled")
end

---Disable sandbox mode (return to normal persistence)
function M.disable_sandbox()
  sandbox_mode = false
  sandbox_data = nil
  sandbox_ui_state = nil
  logger.debug("Sandbox mode disabled")
end

---Check if sandbox mode is enabled
---@return boolean
function M.is_sandbox()
  return sandbox_mode
end

-- ============================================================================
-- Data Persistence - Main Data
-- ============================================================================

---Create default data structure
---@return FavdirData
local function create_default_data()
  local groups = {}
  -- Only create groups if configured
  if config and config.default_groups then
    for i, name in ipairs(config.default_groups) do
      table.insert(groups, {
        name = name,
        items = {},
        order = i,
        children = {},
        dir_links = {},
      })
    end
  end
  return { groups = groups }
end

---Load data from file (or sandbox)
---@return FavdirData
function M.load_data()
  -- Sandbox mode: return in-memory data
  if sandbox_mode then
    return sandbox_data or { groups = {} }
  end

  if not config then
    return create_default_data()
  end

  local path = config.data_file
  if vim.fn.filereadable(path) == 0 then
    return create_default_data()
  end

  local content = vim.fn.readfile(path)
  if #content == 0 then
    return create_default_data()
  end

  local ok, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  if not ok or type(data) ~= "table" or not data.groups then
    logger.warn("Failed to parse data file, using defaults")
    return create_default_data()
  end

  logger.debug("Loaded data with %d groups", #data.groups)

  return data
end

---Save data to file (or sandbox memory)
---@param data FavdirData
---@return boolean success
function M.save_data(data)
  -- Sandbox mode: store in memory only
  if sandbox_mode then
    sandbox_data = data
    return true
  end

  if not config then
    return false
  end

  local path = config.data_file
  local dir = vim.fn.fnamemodify(path, ':h')

  -- Ensure directory exists
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end

  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    logger.error("Failed to encode data")
    return false
  end

  local write_ok = pcall(vim.fn.writefile, { json }, path)
  if not write_ok then
    logger.error("Failed to write data file: %s", path)
    return false
  end

  logger.debug("Saved data to %s", path)
  return true
end

-- ============================================================================
-- Data Persistence - UI State
-- ============================================================================

---Create default UI state
---@return FavdirUIState
local function create_default_ui_state()
  return {
    expanded_groups = {},
    last_selected_group = nil,
    last_selected_type = constants.SELECTION_TYPE.GROUP,
    last_selected_dir_link = nil,
    dir_link_current_path = nil,
    is_browsing_directory = false,
    browse_base_path = nil,
    browse_current_path = nil,
    focused_panel = "left",
    left_cursor = { row = 1, col = 0 },
    right_cursor = { row = 1, col = 0 },
    left_sort_mode = constants.DEFAULTS.LEFT_SORT_MODE,
    right_sort_mode = constants.DEFAULTS.RIGHT_SORT_MODE,
    dir_sort_mode = constants.DEFAULTS.DIR_SORT_MODE,
    left_sort_asc = constants.DEFAULTS.SORT_ASCENDING,
    right_sort_asc = constants.DEFAULTS.SORT_ASCENDING,
    dir_sort_asc = constants.DEFAULTS.SORT_ASCENDING,
  }
end

---Load UI state from file (or sandbox)
---@return FavdirUIState
function M.load_ui_state()
  -- Sandbox mode: return in-memory state or default
  if sandbox_mode then
    if sandbox_ui_state then
      return vim.tbl_deep_extend("force", create_default_ui_state(), sandbox_ui_state)
    end
    return create_default_ui_state()
  end

  if not config then
    return create_default_ui_state()
  end

  local path = config.ui_state_file
  if vim.fn.filereadable(path) == 0 then
    return create_default_ui_state()
  end

  local content = vim.fn.readfile(path)
  if #content == 0 then
    return create_default_ui_state()
  end

  local ok, state = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  if not ok or type(state) ~= "table" then
    return create_default_ui_state()
  end

  -- Merge with defaults to handle missing fields
  return vim.tbl_deep_extend("force", create_default_ui_state(), state)
end

---Save UI state to file (or sandbox memory)
---@param state FavdirUIState
---@return boolean success
function M.save_ui_state(state)
  -- Sandbox mode: store in memory only
  if sandbox_mode then
    sandbox_ui_state = state
    return true
  end

  if not config then
    return false
  end

  local path = config.ui_state_file
  local dir = vim.fn.fnamemodify(path, ':h')

  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end

  local ok, json = pcall(vim.fn.json_encode, state)
  if not ok then
    return false
  end

  local write_ok = pcall(vim.fn.writefile, { json }, path)
  return write_ok == true
end

-- ============================================================================
-- UI State Helpers
-- ============================================================================

---Check if a group is expanded
---@param ui_state FavdirUIState
---@param group_path string
---@return boolean
function M.is_expanded(ui_state, group_path)
  return vim.tbl_contains(ui_state.expanded_groups, group_path)
end

---Toggle group expansion
---@param group_path string
---@return boolean new_state
function M.toggle_expanded(group_path)
  local ui_state = M.load_ui_state()

  if M.is_expanded(ui_state, group_path) then
    ui_state.expanded_groups = vim.tbl_filter(function(p)
      return p ~= group_path
    end, ui_state.expanded_groups)
    M.save_ui_state(ui_state)
    return false
  else
    table.insert(ui_state.expanded_groups, group_path)
    M.save_ui_state(ui_state)
    return true
  end
end

return M
