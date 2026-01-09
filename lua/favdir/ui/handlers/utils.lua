---@module favdir.ui.handlers.utils
---Shared utility functions for handlers

local M = {}

---Get focused panel from current buffer (more reliable than state.focused_panel)
---@param mp_state MultiPanelState
---@return string panel_name
function M.get_focused_panel(mp_state)
  local current_buf = vim.api.nvim_get_current_buf()
  local groups_buf = mp_state:get_panel_buffer("groups")
  local items_buf = mp_state:get_panel_buffer("items")

  if current_buf == groups_buf then
    return "groups"
  elseif current_buf == items_buf then
    return "items"
  end
  -- Fallback to state if buffer check fails
  return mp_state.focused_panel
end

return M
