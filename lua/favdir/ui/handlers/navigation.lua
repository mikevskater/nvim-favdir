---@module favdir.ui.handlers.navigation
---Navigation handlers for favdir (enter, toggle_expand)

local M = {}

local data_module = require("favdir.state.data")
local utils = require("favdir.ui.handlers.utils")
local logger = require("favdir.logger")
local constants = require("favdir.constants")

-- ============================================================================
-- Navigation Handlers
-- ============================================================================

---Handle toggle expand/collapse
---@param mp_state MultiPanelState
function M.handle_toggle_expand(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused ~= constants.PANEL.GROUPS then
    return
  end

  local element = mp_state:get_element_at_cursor()
  local node = utils.get_node(element)
  if not node then return end

  -- Directory links cannot be expanded
  if node.is_dir_link then
    logger.info("Directory links cannot be expanded")
    return
  end

  if node.has_children then
    -- Toggle expansion
    data_module.toggle_expanded(node.full_path)
    mp_state:render_panel(constants.PANEL.GROUPS)
  else
    logger.info("No child groups to expand")
  end
end

---Handle Enter key - select group on left panel, interact on right panel
---@param mp_state MultiPanelState
function M.handle_enter(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused == constants.PANEL.GROUPS then
    -- Explicitly select the group/dir_link under cursor
    local element = mp_state:get_element_at_cursor()
    local node = utils.get_node(element)
    if not node then return end

    utils.modify_ui_state(function(ui_state)
      -- Reset browse state when selecting anything on left panel
      ui_state.is_browsing_directory = false
      ui_state.browse_base_path = nil
      ui_state.browse_current_path = nil

      if node.is_dir_link then
        -- Select this dir_link
        ui_state.last_selected_type = constants.SELECTION_TYPE.DIR_LINK
        ui_state.last_selected_dir_link = node.dir_path
        ui_state.dir_link_current_path = nil
        ui_state.last_selected_group = nil
      else
        -- Select this group
        ui_state.last_selected_type = constants.SELECTION_TYPE.GROUP
        ui_state.last_selected_group = node.full_path
        ui_state.last_selected_dir_link = nil
        ui_state.dir_link_current_path = nil
      end
    end)

    -- Refresh both panels
    mp_state:render_panel(constants.PANEL.GROUPS)
    mp_state:render_panel(constants.PANEL.ITEMS)
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
  if focused ~= constants.PANEL.ITEMS then
    return
  end

  local element = mp_state:get_element_at_cursor()
  local item = utils.get_item(element)
  if not item then
    return
  end

  -- Only browse directories (including parent "..")
  if item.type ~= constants.ITEM_TYPE.DIR and item.type ~= constants.ITEM_TYPE.PARENT then
    logger.info("Not a directory")
    return
  end

  local ui_state = data_module.load_ui_state()

  utils.modify_ui_state(function(state)
    if ui_state.is_browsing_directory then
      -- Already in browse mode (from opening a directory item) - navigate deeper
      state.browse_current_path = item.path
    elseif mp_state._is_dir_link_view then
      -- In dir_link view (selected from left panel) - navigate deeper
      state.dir_link_current_path = item.path
    else
      -- Opening a directory item from a regular group view
      -- Enter browse mode with this directory as the base
      state.is_browsing_directory = true
      state.browse_base_path = item.path
      state.browse_current_path = item.path
    end
  end)

  -- Re-render items panel
  mp_state:render_panel(constants.PANEL.ITEMS)

  -- Move cursor to first item
  mp_state:set_cursor(constants.PANEL.ITEMS, 1, 0)
end

---Handle go up (backspace) - go up one folder level when browsing directories
---@param mp_state MultiPanelState
function M.handle_go_up(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  -- Only works on items panel when in browse mode
  if focused ~= constants.PANEL.ITEMS or not mp_state._is_dir_link_view then
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
    local ui_state = data_module.load_ui_state()
    if ui_state.is_browsing_directory then
      utils.modify_ui_state(function(state)
        state.is_browsing_directory = false
        state.browse_base_path = nil
        state.browse_current_path = nil
      end)
      mp_state:render_panel(constants.PANEL.ITEMS)
      logger.info("Exited directory browse")
    else
      logger.info("Already at top level")
    end
    return
  end

  -- Go up one level
  local parent_path = vim.fn.fnamemodify(current_path, ':h')

  -- Update current path in UI state
  local ui_state = data_module.load_ui_state()
  utils.modify_ui_state(function(state)
    if ui_state.is_browsing_directory then
      state.browse_current_path = parent_path
    else
      state.dir_link_current_path = parent_path
    end
  end)

  -- Re-render items panel
  mp_state:render_panel(constants.PANEL.ITEMS)
end

return M
