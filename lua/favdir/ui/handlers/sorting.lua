---@module favdir.ui.handlers.sorting
---Sorting and reordering handlers for favdir

local M = {}

local state_module = require("favdir.state")

-- ============================================================================
-- Sort Handler
-- ============================================================================

---Handle Sort key
---@param mp_state MultiPanelState
function M.handle_sort(mp_state)
  local focused = mp_state.focused_panel
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

    vim.notify("Groups sorted: " .. next_mode, vim.log.levels.INFO)
    mp_state:render_panel("groups")
  else
    local group_path = ui_state.last_selected_group
    if not group_path then
      vim.notify("Select a group first", vim.log.levels.WARN)
      return
    end

    local modes = { "custom", "alpha", "type" }
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

    -- Persist sort order to data file
    state_module.sort_items(group_path, next_mode)

    vim.notify("Items sorted: " .. next_mode, vim.log.levels.INFO)
    mp_state:render_panel("items")
  end
end

-- ============================================================================
-- Reorder Handlers
-- ============================================================================

---Handle move up (reorder)
---@param mp_state MultiPanelState
function M.handle_move_up(mp_state)
  local focused = mp_state.focused_panel
  local ui_state = state_module.load_ui_state()

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  if focused == "groups" then
    if ui_state.left_sort_mode ~= "custom" then
      vim.notify("Reorder only works in custom sort mode", vim.log.levels.INFO)
      return
    end

    local node = element.data.node
    if not node then return end

    -- Get parent path
    local parts = vim.split(node.full_path, ".", { plain = true })
    local parent_path = #parts > 1 and table.concat(vim.list_slice(parts, 1, #parts - 1), ".") or ""

    -- Find index in parent's children
    local data = state_module.load_data()
    local parent_list = parent_path == "" and data.groups or (state_module.find_group(data, parent_path) or {}).children or {}
    local idx = 0
    for i, g in ipairs(parent_list) do
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
    if ui_state.right_sort_mode ~= "custom" then
      vim.notify("Reorder only works in custom sort mode", vim.log.levels.INFO)
      return
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
  local focused = mp_state.focused_panel
  local ui_state = state_module.load_ui_state()

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  if focused == "groups" then
    if ui_state.left_sort_mode ~= "custom" then
      vim.notify("Reorder only works in custom sort mode", vim.log.levels.INFO)
      return
    end

    local node = element.data.node
    if not node then return end

    local parts = vim.split(node.full_path, ".", { plain = true })
    local parent_path = #parts > 1 and table.concat(vim.list_slice(parts, 1, #parts - 1), ".") or ""

    local data = state_module.load_data()
    local parent_list = parent_path == "" and data.groups or (state_module.find_group(data, parent_path) or {}).children or {}
    local idx = 0
    for i, g in ipairs(parent_list) do
      if g.name == node.name then
        idx = i
        break
      end
    end

    if idx < #parent_list then
      local row = mp_state:get_cursor("groups")
      state_module.reorder_down("group", parent_path, idx)
      mp_state:render_panel("groups")
      mp_state:set_cursor("groups", row + 1)
    end
  else
    if ui_state.right_sort_mode ~= "custom" then
      vim.notify("Reorder only works in custom sort mode", vim.log.levels.INFO)
      return
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
