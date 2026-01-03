---@module favdir.ui.handlers.navigation
---Navigation handlers for favdir (enter, toggle_expand)

local M = {}

local state_module = require("favdir.state")

-- ============================================================================
-- Navigation Handlers
-- ============================================================================

---Handle toggle expand/collapse
---@param mp_state MultiPanelState
function M.handle_toggle_expand(mp_state)
  local focused = mp_state.focused_panel

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

---Handle Enter key - uses interact_at_cursor for element-based interaction
---@param mp_state MultiPanelState
function M.handle_enter(mp_state)
  mp_state:interact_at_cursor()
end

return M
