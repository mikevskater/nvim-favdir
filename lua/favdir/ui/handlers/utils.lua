---@module favdir.ui.handlers.utils
---Shared utility functions for handlers

local M = {}

local data_module = require("favdir.state.data")
local constants = require("favdir.constants")

-- ============================================================================
-- Panel Focus
-- ============================================================================

---Get focused panel from current buffer (more reliable than state.focused_panel)
---@param mp_state MultiPanelState
---@return string panel_name
function M.get_focused_panel(mp_state)
  local current_buf = vim.api.nvim_get_current_buf()
  local groups_buf = mp_state:get_panel_buffer(constants.PANEL.GROUPS)
  local items_buf = mp_state:get_panel_buffer(constants.PANEL.ITEMS)

  if current_buf == groups_buf then
    return constants.PANEL.GROUPS
  elseif current_buf == items_buf then
    return constants.PANEL.ITEMS
  end
  -- Fallback to state if buffer check fails
  return mp_state.focused_panel
end

-- ============================================================================
-- Panel Refresh
-- ============================================================================

---Safely re-render panels after state change
---Wraps the render call in vim.schedule and checks mp_state validity
---@param mp_state MultiPanelState
---@param panels "both"|"groups"|"items"|string[] Which panels to refresh
function M.refresh_panels(mp_state, panels)
  vim.schedule(function()
    if not mp_state or not mp_state:is_valid() then
      return
    end

    if panels == "both" then
      mp_state:render_panel(constants.PANEL.GROUPS)
      mp_state:render_panel(constants.PANEL.ITEMS)
    elseif panels == constants.PANEL.GROUPS or panels == constants.PANEL.ITEMS then
      mp_state:render_panel(panels)
    elseif type(panels) == "table" then
      for _, panel in ipairs(panels) do
        mp_state:render_panel(panel)
      end
    end
  end)
end

-- ============================================================================
-- Element Data Extraction
-- ============================================================================

---Get TreeNode from element if available
---@param element TrackedElement?
---@return TreeNode?
function M.get_node(element)
  if element and element.data then
    return element.data.node
  end
  return nil
end

---Get FavdirItem from element if available
---@param element TrackedElement?
---@return FavdirItem?
function M.get_item(element)
  if element and element.data then
    return element.data.item
  end
  return nil
end

---Get group_path from element if available
---@param element TrackedElement?
---@return string?
function M.get_group_path(element)
  if element and element.data then
    return element.data.group_path
  end
  return nil
end

---Get item index from element if available
---@param element TrackedElement?
---@return number?
function M.get_item_index(element)
  if element and element.data then
    return element.data.index
  end
  return nil
end

-- ============================================================================
-- View Mode Detection
-- ============================================================================

---Check if currently viewing a directory (dir_link or browse mode)
---@return boolean
function M.is_directory_view()
  local ui_state = data_module.load_ui_state()
  return ui_state.last_selected_type == constants.SELECTION_TYPE.DIR_LINK
      or ui_state.is_browsing_directory == true
end

-- ============================================================================
-- UI State Modification
-- ============================================================================

---Modify UI state with a callback (load, modify, save pattern)
---This handles the common pattern of loading state, modifying it, and saving it back
---@param modifier fun(state: FavdirUIState)
function M.modify_ui_state(modifier)
  local ui_state = data_module.load_ui_state()
  modifier(ui_state)
  data_module.save_ui_state(ui_state)
end

return M
