---@module favdir.ui.handlers.sorting
---Sorting and reordering handlers for favdir

local M = {}

local state_module = require("favdir.state")
local utils = require("favdir.ui.handlers.utils")
local logger = require("favdir.logger")
local path_utils = require("favdir.path_utils")

-- ============================================================================
-- Sort Handler
-- ============================================================================

---Handle Sort key
---@param mp_state MultiPanelState
function M.handle_sort(mp_state)
  local focused = utils.get_focused_panel(mp_state)
  local ui_state = state_module.load_ui_state()

  if focused == "groups" then
    local modes = { "custom", "alpha" }
    local current = ui_state.left_sort_mode or "custom"
    local idx = 1
    for i, m in ipairs(modes) do
      if m == current then
        idx = i
        break
      end
    end
    local next_mode = modes[(idx % #modes) + 1]
    ui_state.left_sort_mode = next_mode
    state_module.save_ui_state(ui_state)

    -- Apply sort to root groups
    state_module.sort_groups("", next_mode)

    logger.info("Groups sorted: %s", next_mode)
    mp_state:render_panel("groups")
  else
    -- Check if we're viewing a dir_link (filesystem browser) vs group items
    local is_dir_view = ui_state.last_selected_type == "dir_link" or ui_state.is_browsing_directory

    if is_dir_view then
      -- Dir_link/directory view sorting modes
      local modes = { "name", "created", "modified", "size", "type" }
      local current = ui_state.dir_sort_mode or "type"
      local idx = 1
      for i, m in ipairs(modes) do
        if m == current then
          idx = i
          break
        end
      end
      local next_mode = modes[(idx % #modes) + 1]
      ui_state.dir_sort_mode = next_mode
      state_module.save_ui_state(ui_state)

      logger.info("Directory sorted: %s", next_mode)
      mp_state:render_panel("items")
    else
      -- Regular group items sorting
      -- Try to get group_path from element data first, then fallback to ui_state
      local group_path = nil
      local element = mp_state:get_element_at_cursor()
      if element and element.data and element.data.group_path then
        group_path = element.data.group_path
      else
        group_path = ui_state.last_selected_group
      end

      if not group_path then
        logger.warn("Select a group first")
        return
      end

      local modes = { "custom", "name", "created", "modified", "size", "type" }
      local current = ui_state.right_sort_mode or "custom"
      local idx = 1
      for i, m in ipairs(modes) do
        if m == current then
          idx = i
          break
        end
      end
      local next_mode = modes[(idx % #modes) + 1]
      ui_state.right_sort_mode = next_mode
      state_module.save_ui_state(ui_state)

      logger.info("Items sorted: %s", next_mode)
      mp_state:render_panel("items")
    end
  end
end

---Handle Sort Order toggle (asc/desc)
---@param mp_state MultiPanelState
function M.handle_sort_order(mp_state)
  local focused = utils.get_focused_panel(mp_state)
  local ui_state = state_module.load_ui_state()

  local order_name
  if focused == "groups" then
    ui_state.left_sort_asc = not ui_state.left_sort_asc
    order_name = ui_state.left_sort_asc and "ascending" or "descending"
    state_module.save_ui_state(ui_state)
    mp_state:render_panel("groups")
  else
    local is_dir_view = ui_state.last_selected_type == "dir_link" or ui_state.is_browsing_directory
    if is_dir_view then
      ui_state.dir_sort_asc = not ui_state.dir_sort_asc
      order_name = ui_state.dir_sort_asc and "ascending" or "descending"
    else
      ui_state.right_sort_asc = not ui_state.right_sort_asc
      order_name = ui_state.right_sort_asc and "ascending" or "descending"
    end
    state_module.save_ui_state(ui_state)
    mp_state:render_panel("items")
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
  local ui_state = state_module.load_ui_state()
  ui_state.right_sort_mode = "custom"
  state_module.save_ui_state(ui_state)

  return true
end

---Handle move up (reorder)
---@param mp_state MultiPanelState
function M.handle_move_up(mp_state)
  local focused = utils.get_focused_panel(mp_state)
  local ui_state = state_module.load_ui_state()

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  if focused == "groups" then
    if ui_state.left_sort_mode ~= "custom" then
      -- Freeze current order and switch to custom mode
      state_module.freeze_groups_order()
      ui_state.left_sort_mode = "custom"
      state_module.save_ui_state(ui_state)
      mp_state:render_panel("groups")
      logger.info("Switched to custom sort mode")
    end

    local node = element.data.node
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
      local row = mp_state:get_cursor("groups")
      state_module.reorder_up("group", parent_path, idx)
      mp_state:render_panel("groups")
      mp_state:set_cursor("groups", row - 1)
    end
  else
    -- Check if we're in a dir_link view (can't reorder filesystem)
    if ui_state.last_selected_type == "dir_link" or ui_state.is_browsing_directory then
      logger.info("Cannot reorder directory contents")
      return
    end

    if ui_state.right_sort_mode ~= "custom" then
      -- Freeze current order and switch to custom mode
      local group_path = element.data.group_path
      if group_path and freeze_items_order(mp_state, group_path) then
        mp_state:render_panel("items")
        logger.info("Switched to custom sort mode")
      end
    end

    local group_path = element.data.group_path
    local index = element.data.index
    if not group_path or not index then return end

    if index > 1 then
      local row = mp_state:get_cursor("items")
      state_module.reorder_up("item", group_path, index)
      mp_state:render_panel("items")
      mp_state:set_cursor("items", row - 1)
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

  if focused == "groups" then
    if ui_state.left_sort_mode ~= "custom" then
      -- Freeze current order and switch to custom mode
      state_module.freeze_groups_order()
      ui_state.left_sort_mode = "custom"
      state_module.save_ui_state(ui_state)
      mp_state:render_panel("groups")
      logger.info("Switched to custom sort mode")
    end

    local node = element.data.node
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
      local row = mp_state:get_cursor("groups")
      state_module.reorder_down("group", parent_path, idx)
      mp_state:render_panel("groups")
      mp_state:set_cursor("groups", row + 1)
    end
  else
    -- Check if we're in a dir_link view (can't reorder filesystem)
    if ui_state.last_selected_type == "dir_link" or ui_state.is_browsing_directory then
      logger.info("Cannot reorder directory contents")
      return
    end

    if ui_state.right_sort_mode ~= "custom" then
      -- Freeze current order and switch to custom mode
      local group_path = element.data.group_path
      if group_path and freeze_items_order(mp_state, group_path) then
        mp_state:render_panel("items")
        logger.info("Switched to custom sort mode")
      end
    end

    local group_path = element.data.group_path
    local index = element.data.index
    if not group_path or not index then return end

    -- Get total items count
    local items_count = mp_state._sorted_items and #mp_state._sorted_items or 0

    if index < items_count then
      local row = mp_state:get_cursor("items")
      state_module.reorder_down("item", group_path, index)
      mp_state:render_panel("items")
      mp_state:set_cursor("items", row + 1)
    end
  end
end

return M
