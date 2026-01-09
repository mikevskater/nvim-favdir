---@module favdir.ui.handlers.opening
---Open handlers for favdir (split, vsplit, tab)

local M = {}

local utils = require("favdir.ui.handlers.utils")

-- ============================================================================
-- Open in Split Handler
-- ============================================================================

---Handle open in split
---@param mp_state MultiPanelState
---@param split_cmd string "split" or "vsplit" or "tabnew"
function M.handle_open_split(mp_state, split_cmd)
  if utils.get_focused_panel(mp_state) ~= "items" then
    vim.notify("Select an item in the right panel", vim.log.levels.INFO)
    return
  end

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  local item = element.data.item
  if not item then return end

  mp_state:close()

  vim.cmd(split_cmd)
  if item.type == "dir" then
    vim.cmd.cd(item.path)
  else
    vim.cmd.edit(item.path)
  end
end

return M
