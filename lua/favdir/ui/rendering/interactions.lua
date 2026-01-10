---@module favdir.ui.rendering.interactions
---Interaction handlers for panel elements

local M = {}

local data_module = require("favdir.state.data")
local logger = require("favdir.logger")
local constants = require("favdir.constants")

-- ============================================================================
-- Interaction Handlers (called from element tracking)
-- ============================================================================

---Handle group/dir_link element interaction (Enter key) - only selects, doesn't toggle
---@param element TrackedElement
---@param mp_state MultiPanelState
function M.on_group_interact(element, mp_state)
  if not element or not element.data then return end

  local node = element.data.node
  if not node then return end

  local ui_state = data_module.load_ui_state()

  -- Reset browse state when selecting anything on left panel
  ui_state.is_browsing_directory = false
  ui_state.browse_base_path = nil
  ui_state.browse_current_path = nil

  if node.is_dir_link then
    -- Select this dir_link (reset navigation to base path)
    ui_state.last_selected_type = constants.SELECTION_TYPE.DIR_LINK
    ui_state.last_selected_dir_link = node.dir_path
    ui_state.dir_link_current_path = nil -- Reset to base path
    ui_state.last_selected_group = nil
  else
    -- Select this group (don't toggle - that's handled by 'o' key)
    ui_state.last_selected_type = constants.SELECTION_TYPE.GROUP
    ui_state.last_selected_group = node.full_path
    ui_state.last_selected_dir_link = nil
    ui_state.dir_link_current_path = nil
  end

  data_module.save_ui_state(ui_state)

  -- Refresh both panels
  mp_state:render_panel(constants.PANEL.GROUPS)
  mp_state:render_panel(constants.PANEL.ITEMS)
end

---Handle item element interaction (Enter key)
---@param element TrackedElement
---@param mp_state MultiPanelState
function M.on_item_interact(element, mp_state)
  if not element or not element.data then return end

  local item = element.data.item
  if not item then return end

  -- Handle "../" parent entry - trigger go up navigation instead of opening
  if item.type == constants.ITEM_TYPE.PARENT then
    local navigation = require("favdir.ui.handlers.navigation")
    navigation.handle_go_up(mp_state)
    return
  end

  -- Close the UI first
  mp_state:close()

  if item.type == constants.ITEM_TYPE.DIR then
    vim.cmd.cd(item.path)
    logger.info("Changed to: %s", item.path)
  else
    vim.cmd.edit(item.path)
  end
end

return M
