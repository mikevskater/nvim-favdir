---@class FavdirState
---Data persistence and state management for favdir
---@module favdir.state

local M = {}

-- Import submodules
local data_module = require("favdir.state.data")
local groups_module = require("favdir.state.groups")
local items_module = require("favdir.state.items")
local sorting_module = require("favdir.state.sorting")

-- ============================================================================
-- Initialization
-- ============================================================================

---Initialize the state module with config
---@param cfg FavdirConfig
function M.init(cfg)
  data_module.init(cfg)
end

-- ============================================================================
-- Re-export Data Module Functions
-- ============================================================================

M.load_data = data_module.load_data
M.save_data = data_module.save_data
M.load_ui_state = data_module.load_ui_state
M.save_ui_state = data_module.save_ui_state

-- ============================================================================
-- Re-export Groups Module Functions
-- ============================================================================

M.find_group = groups_module.find_group
M.get_group_list = groups_module.get_group_list
M.add_group = groups_module.add_group
M.remove_group = groups_module.remove_group
M.rename_group = groups_module.rename_group
M.move_group = groups_module.move_group

-- ============================================================================
-- Re-export Items Module Functions
-- ============================================================================

M.add_item = items_module.add_item
M.remove_item = items_module.remove_item
M.move_item = items_module.move_item

-- ============================================================================
-- Re-export Sorting Module Functions
-- ============================================================================

M.sort_groups = sorting_module.sort_groups
M.sort_items = sorting_module.sort_items
M.reorder_up = sorting_module.reorder_up
M.reorder_down = sorting_module.reorder_down

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
