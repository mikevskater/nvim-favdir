---@module favdir.ui.handlers.sorting
---Sorting and reordering handlers for favdir

local M = {}

local state_module = require("favdir.state")
local utils = require("favdir.ui.handlers.utils")
local logger = require("favdir.logger")
local path_utils = require("favdir.path_utils")
local constants = require("favdir.constants")

-- ============================================================================
-- Sort Handler
-- ============================================================================

---Handle Sort key
---@param mp_state MultiPanelState
function M.handle_sort(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused == constants.PANEL.GROUPS then
    local ui_state = state_module.load_ui_state()
    local modes = constants.LEFT_SORT_MODES
    local current = ui_state.left_sort_mode or constants.DEFAULTS.LEFT_SORT_MODE
    local idx = 1
    for i, m in ipairs(modes) do
      if m == current then
        idx = i
        break
      end
    end
    local next_mode = modes[(idx % #modes) + 1]

    utils.modify_ui_state(function(state)
      state.left_sort_mode = next_mode
    end)

    -- Apply sort to root groups
    state_module.sort_groups("", next_mode)

    logger.info("Groups sorted: %s", next_mode)
    mp_state:render_panel(constants.PANEL.GROUPS)
  else
    -- Check if we're viewing a dir_link (filesystem browser) vs group items
    if utils.is_directory_view() then
      -- Dir_link/directory view sorting modes
      local ui_state = state_module.load_ui_state()
      local modes = constants.DIR_SORT_MODES
      local current = ui_state.dir_sort_mode or constants.DEFAULTS.DIR_SORT_MODE
      local idx = 1
      for i, m in ipairs(modes) do
        if m == current then
          idx = i
          break
        end
      end
      local next_mode = modes[(idx % #modes) + 1]

      utils.modify_ui_state(function(state)
        state.dir_sort_mode = next_mode
      end)

      logger.info("Directory sorted: %s", next_mode)
      mp_state:render_panel(constants.PANEL.ITEMS)
    else
      -- Regular group items sorting
      -- Try to get group_path from element data first, then fallback to ui_state
      local element = mp_state:get_element_at_cursor()
      local group_path = utils.get_group_path(element)
      if not group_path then
        local ui_state = state_module.load_ui_state()
        group_path = ui_state.last_selected_group
      end

      if not group_path then
        logger.warn("Select a group first")
        return
      end

      local ui_state = state_module.load_ui_state()
      local modes = constants.RIGHT_SORT_MODES
      local current = ui_state.right_sort_mode or constants.DEFAULTS.RIGHT_SORT_MODE
      local idx = 1
      for i, m in ipairs(modes) do
        if m == current then
          idx = i
          break
        end
      end
      local next_mode = modes[(idx % #modes) + 1]

      utils.modify_ui_state(function(state)
        state.right_sort_mode = next_mode
      end)

      logger.info("Items sorted: %s", next_mode)
      mp_state:render_panel(constants.PANEL.ITEMS)
    end
  end
end

---Handle Sort Order toggle (asc/desc)
---@param mp_state MultiPanelState
function M.handle_sort_order(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  local order_name
  if focused == constants.PANEL.GROUPS then
    local ui_state = state_module.load_ui_state()
    local new_asc = not ui_state.left_sort_asc
    order_name = new_asc and "ascending" or "descending"

    utils.modify_ui_state(function(state)
      state.left_sort_asc = new_asc
    end)
    mp_state:render_panel(constants.PANEL.GROUPS)
  else
    local ui_state = state_module.load_ui_state()
    if utils.is_directory_view() then
      local new_asc = not ui_state.dir_sort_asc
      order_name = new_asc and "ascending" or "descending"
      utils.modify_ui_state(function(state)
        state.dir_sort_asc = new_asc
      end)
    else
      local new_asc = not ui_state.right_sort_asc
      order_name = new_asc and "ascending" or "descending"
      utils.modify_ui_state(function(state)
        state.right_sort_asc = new_asc
      end)
    end
    mp_state:render_panel(constants.PANEL.ITEMS)
  end

  logger.info("Sort order: %s", order_name)
end

-- ============================================================================
-- Reorder Handlers
-- ============================================================================

---Freeze current sort order as custom order for items
---@param mp_state MultiPanelState
---@param group_path string
---@return boolean success
local function freeze_items_order(mp_state, group_path)
  local sorted_items = mp_state._sorted_items
  if not sorted_items then return false end

  -- Update order fields to match current display order
  for i, item in ipairs(sorted_items) do
    item.order = i
  end

  -- Save to data file
  local data = state_module.load_data()
  local group = state_module.find_group(data, group_path)
  if group then
    group.items = sorted_items
    state_module.save_data(data)
  end

  -- Switch to custom mode
  utils.modify_ui_state(function(state)
    state.right_sort_mode = constants.SORT_MODE.CUSTOM
  end)

  return true
end

---Handle move up (reorder)
---@param mp_state MultiPanelState
function M.handle_move_up(mp_state)
  local focused = utils.get_focused_panel(mp_state)
  local ui_state = state_module.load_ui_state()

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  if focused == constants.PANEL.GROUPS then
    if ui_state.left_sort_mode ~= constants.SORT_MODE.CUSTOM then
      -- Freeze current order and switch to custom mode
      state_module.freeze_groups_order()
      utils.modify_ui_state(function(state)
        state.left_sort_mode = constants.SORT_MODE.CUSTOM
      end)
      mp_state:render_panel(constants.PANEL.GROUPS)
      logger.info("Switched to custom sort mode")
    end

    local node = utils.get_node(element)
    if not node then return end

    -- Get parent path
    local parent_path = path_utils.get_parent_path(node.full_path)

    -- Find index in parent's children (using current sorted order)
    local data = state_module.load_data()
    local parent_list = parent_path == "" and data.groups or (state_module.find_group(data, parent_path) or {}).children or {}

    -- Sort by order to get current display order
    local sorted = vim.tbl_values(parent_list)
    table.sort(sorted, function(a, b)
      return (a.order or 0) < (b.order or 0)
    end)

    local idx = 0
    for i, g in ipairs(sorted) do
      if g.name == node.name then
        idx = i
        break
      end
    end

    if idx > 1 then
      local row = mp_state:get_cursor(constants.PANEL.GROUPS)
      state_module.reorder_up(constants.ITEM_TYPE.GROUP, parent_path, idx)
      mp_state:render_panel(constants.PANEL.GROUPS)
      mp_state:set_cursor(constants.PANEL.GROUPS, row - 1)
    end
  else
    -- Check if we're in a dir_link view (can't reorder filesystem)
    if utils.is_directory_view() then
      logger.info("Cannot reorder directory contents")
      return
    end

    if ui_state.right_sort_mode ~= constants.SORT_MODE.CUSTOM then
      -- Freeze current order and switch to custom mode
      local group_path = utils.get_group_path(element)
      if group_path and freeze_items_order(mp_state, group_path) then
        mp_state:render_panel(constants.PANEL.ITEMS)
        logger.info("Switched to custom sort mode")
      end
    end

    local group_path = utils.get_group_path(element)
    local index = utils.get_item_index(element)
    if not group_path or not index then return end

    if index > 1 then
      local row = mp_state:get_cursor(constants.PANEL.ITEMS)
      state_module.reorder_up("item", group_path, index)
      mp_state:render_panel(constants.PANEL.ITEMS)
      mp_state:set_cursor(constants.PANEL.ITEMS, row - 1)
    end
  end
end

---Handle move down (reorder)
---@param mp_state MultiPanelState
function M.handle_move_down(mp_state)
  local focused = utils.get_focused_panel(mp_state)
  local ui_state = state_module.load_ui_state()

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  if focused == constants.PANEL.GROUPS then
    if ui_state.left_sort_mode ~= constants.SORT_MODE.CUSTOM then
      -- Freeze current order and switch to custom mode
      state_module.freeze_groups_order()
      utils.modify_ui_state(function(state)
        state.left_sort_mode = constants.SORT_MODE.CUSTOM
      end)
      mp_state:render_panel(constants.PANEL.GROUPS)
      logger.info("Switched to custom sort mode")
    end

    local node = utils.get_node(element)
    if not node then return end

    local parent_path = path_utils.get_parent_path(node.full_path)

    local data = state_module.load_data()
    local parent_list = parent_path == "" and data.groups or (state_module.find_group(data, parent_path) or {}).children or {}

    -- Sort by order to get current display order
    local sorted = vim.tbl_values(parent_list)
    table.sort(sorted, function(a, b)
      return (a.order or 0) < (b.order or 0)
    end)

    local idx = 0
    for i, g in ipairs(sorted) do
      if g.name == node.name then
        idx = i
        break
      end
    end

    if idx > 0 and idx < #sorted then
      local row = mp_state:get_cursor(constants.PANEL.GROUPS)
      state_module.reorder_down(constants.ITEM_TYPE.GROUP, parent_path, idx)
      mp_state:render_panel(constants.PANEL.GROUPS)
      mp_state:set_cursor(constants.PANEL.GROUPS, row + 1)
    end
  else
    -- Check if we're in a dir_link view (can't reorder filesystem)
    if utils.is_directory_view() then
      logger.info("Cannot reorder directory contents")
      return
    end

    if ui_state.right_sort_mode ~= constants.SORT_MODE.CUSTOM then
      -- Freeze current order and switch to custom mode
      local group_path = utils.get_group_path(element)
      if group_path and freeze_items_order(mp_state, group_path) then
        mp_state:render_panel(constants.PANEL.ITEMS)
        logger.info("Switched to custom sort mode")
      end
    end

    local group_path = utils.get_group_path(element)
    local index = utils.get_item_index(element)
    if not group_path or not index then return end

    -- Get total items count
    local items_count = mp_state._sorted_items and #mp_state._sorted_items or 0

    if index < items_count then
      local row = mp_state:get_cursor(constants.PANEL.ITEMS)
      state_module.reorder_down("item", group_path, index)
      mp_state:render_panel(constants.PANEL.ITEMS)
      mp_state:set_cursor(constants.PANEL.ITEMS, row + 1)
    end
  end
end

return M
