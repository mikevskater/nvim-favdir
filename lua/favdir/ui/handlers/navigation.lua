---@module favdir.ui.handlers.navigation
---Navigation handlers for favdir (enter, toggle_expand)

local M = {}

local state_module = require("favdir.state")
local utils = require("favdir.ui.handlers.utils")

-- ============================================================================
-- Navigation Handlers
-- ============================================================================

---Handle toggle expand/collapse
---@param mp_state MultiPanelState
function M.handle_toggle_expand(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused ~= "groups" then
    return
  end

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  local node = element.data.node
  if not node then return end

  -- Directory links cannot be expanded
  if node.is_dir_link then
    vim.notify("Directory links cannot be expanded", vim.log.levels.INFO)
    return
  end

  if node.has_children then
    -- Toggle expansion
    state_module.toggle_expanded(node.full_path)
    mp_state:render_panel("groups")
  else
    vim.notify("No child groups to expand", vim.log.levels.INFO)
  end
end

---Handle Enter key - select group on left panel, interact on right panel
---@param mp_state MultiPanelState
function M.handle_enter(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused == "groups" then
    -- Explicitly select the group/dir_link under cursor
    local element = mp_state:get_element_at_cursor()
    if not element or not element.data then return end

    local node = element.data.node
    if not node then return end

    local ui_state = state_module.load_ui_state()

    -- Reset browse state when selecting anything on left panel
    ui_state.is_browsing_directory = false
    ui_state.browse_base_path = nil
    ui_state.browse_current_path = nil

    if node.is_dir_link then
      -- Select this dir_link
      ui_state.last_selected_type = "dir_link"
      ui_state.last_selected_dir_link = node.dir_path
      ui_state.dir_link_current_path = nil
      ui_state.last_selected_group = nil
    else
      -- Select this group
      ui_state.last_selected_type = "group"
      ui_state.last_selected_group = node.full_path
      ui_state.last_selected_dir_link = nil
      ui_state.dir_link_current_path = nil
    end

    state_module.save_ui_state(ui_state)

    -- Refresh both panels
    mp_state:render_panel("groups")
    mp_state:render_panel("items")
  else
    -- On items panel, use interact_at_cursor to open file/dir
    mp_state:interact_at_cursor()
  end
end

-- ============================================================================
-- Directory Link Folder Navigation
-- ============================================================================

---Handle browse folder (o key) - enter a folder to show its contents
---Works for both dir_link views and regular group directory items
---@param mp_state MultiPanelState
function M.handle_browse_folder(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  -- Only works on items panel
  if focused ~= "items" then
    return
  end

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then
    return
  end

  local item = element.data.item
  if not item then
    return
  end

  -- Only browse directories (including parent "..")
  if item.type ~= "dir" and item.type ~= "parent" then
    vim.notify("Not a directory", vim.log.levels.INFO)
    return
  end

  local ui_state = state_module.load_ui_state()

  if ui_state.is_browsing_directory then
    -- Already in browse mode (from opening a directory item) - navigate deeper
    ui_state.browse_current_path = item.path
  elseif mp_state._is_dir_link_view then
    -- In dir_link view (selected from left panel) - navigate deeper
    ui_state.dir_link_current_path = item.path
  else
    -- Opening a directory item from a regular group view
    -- Enter browse mode with this directory as the base
    ui_state.is_browsing_directory = true
    ui_state.browse_base_path = item.path
    ui_state.browse_current_path = item.path
  end

  state_module.save_ui_state(ui_state)

  -- Re-render items panel
  mp_state:render_panel("items")

  -- Move cursor to first item
  mp_state:set_cursor("items", 1, 0)
end

---Handle go up (backspace) - go up one folder level when browsing directories
---@param mp_state MultiPanelState
function M.handle_go_up(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  -- Only works on items panel when in browse mode
  if focused ~= "items" or not mp_state._is_dir_link_view then
    return
  end

  local base_path = mp_state._dir_link_base_path
  local current_path = mp_state._dir_link_current_path

  if not base_path or not current_path then
    return
  end

  -- Normalize paths for comparison
  local base_normalized = vim.fn.fnamemodify(base_path, ':p')
  local current_normalized = vim.fn.fnamemodify(current_path, ':p')

  -- Check if already at base path
  if base_normalized == current_normalized then
    -- If we entered browse mode from a group item, exit browse mode
    local ui_state = state_module.load_ui_state()
    if ui_state.is_browsing_directory then
      ui_state.is_browsing_directory = false
      ui_state.browse_base_path = nil
      ui_state.browse_current_path = nil
      state_module.save_ui_state(ui_state)
      mp_state:render_panel("items")
      vim.notify("Exited directory browse", vim.log.levels.INFO)
    else
      vim.notify("Already at top level", vim.log.levels.INFO)
    end
    return
  end

  -- Go up one level
  local parent_path = vim.fn.fnamemodify(current_path, ':h')

  -- Update current path in UI state
  local ui_state = state_module.load_ui_state()
  if ui_state.is_browsing_directory then
    ui_state.browse_current_path = parent_path
  else
    ui_state.dir_link_current_path = parent_path
  end
  state_module.save_ui_state(ui_state)

  -- Re-render items panel
  mp_state:render_panel("items")
end

return M
