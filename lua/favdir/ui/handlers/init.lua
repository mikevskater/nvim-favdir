---@module favdir.ui.handlers
---Handler exports for favdir

local M = {}

-- Import handler modules
local navigation = require("favdir.ui.handlers.navigation")
local editing = require("favdir.ui.handlers.editing")
local sorting = require("favdir.ui.handlers.sorting")
local opening = require("favdir.ui.handlers.opening")

-- ============================================================================
-- Re-export Navigation Handlers
-- ============================================================================

M.handle_enter = navigation.handle_enter
M.handle_toggle_expand = navigation.handle_toggle_expand
M.handle_browse_folder = navigation.handle_browse_folder
M.handle_go_up = navigation.handle_go_up

-- ============================================================================
-- Re-export Editing Handlers
-- ============================================================================

M.handle_add = editing.handle_add
M.handle_delete = editing.handle_delete
M.handle_rename = editing.handle_rename
M.handle_move = editing.handle_move
M.handle_move_group = editing.handle_move_group

-- ============================================================================
-- Re-export Sorting Handlers
-- ============================================================================

M.handle_sort = sorting.handle_sort
M.handle_sort_order = sorting.handle_sort_order
M.handle_move_up = sorting.handle_move_up
M.handle_move_down = sorting.handle_move_down

-- ============================================================================
-- Re-export Opening Handlers
-- ============================================================================

M.handle_open_split = opening.handle_open_split

return M
