---@class FavdirState
---Data persistence and state management for favdir
---@module favdir.state

local M = {}

-- Import submodules
local data_module = require("nvim-favdir.state.data")
local groups_module = require("nvim-favdir.state.groups")
local items_module = require("nvim-favdir.state.items")
local sorting_module = require("nvim-favdir.state.sorting")
local utils_module = require("nvim-favdir.state.utils")
local dir_links_module = require("nvim-favdir.state.dir_links")

-- Wire up cross-module dependencies
dir_links_module.set_groups_module(groups_module)

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
-- Re-export Directory Links Module Functions
-- ============================================================================

M.add_dir_link = dir_links_module.add_dir_link
M.remove_dir_link = dir_links_module.remove_dir_link
M.find_dir_link = dir_links_module.find_dir_link

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
M.freeze_groups_order = sorting_module.freeze_groups_order

-- ============================================================================
-- Re-export Utils Module Functions (for internal/advanced use)
-- ============================================================================

M.utils = utils_module -- Expose full module for advanced use
M.get_next_order = utils_module.get_next_order
M.renumber_order = utils_module.renumber_order

-- ============================================================================
-- Re-export UI State Helpers (from data module)
-- ============================================================================

M.is_expanded = data_module.is_expanded
M.toggle_expanded = data_module.toggle_expanded

-- ============================================================================
-- Re-export Sandbox Functions (from data module)
-- ============================================================================

M.enable_sandbox = data_module.enable_sandbox
M.disable_sandbox = data_module.disable_sandbox
M.is_sandbox = data_module.is_sandbox

return M
