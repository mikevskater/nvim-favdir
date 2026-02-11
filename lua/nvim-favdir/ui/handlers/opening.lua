---@module favdir.ui.handlers.opening
---Open handlers for favdir (split, vsplit, tab)

local M = {}

local utils = require("nvim-favdir.ui.handlers.utils")
local logger = require("nvim-favdir.logger")
local constants = require("nvim-favdir.constants")

-- ============================================================================
-- Open in Split Handler
-- ============================================================================

---Handle open in split
---@param mp_state MultiPanelState
---@param split_cmd string "split" or "vsplit" or "tabnew"
function M.handle_open_split(mp_state, split_cmd)
  if utils.get_focused_panel(mp_state) ~= "items" then
    logger.info("Select an item in the right panel")
    return
  end

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  local item = element.data.item
  if not item then return end

  mp_state:close()

  vim.cmd(split_cmd)
  local escaped = vim.fn.fnameescape(item.path)
  if item.type == constants.ITEM_TYPE.DIR then
    local data_module = require("nvim-favdir.state.data")
    local config = data_module.get_config()
    local cd_cmd = config and config.cd_command or "cd"
    vim.cmd[cd_cmd](escaped)
  else
    vim.cmd.edit(escaped)
  end
end

return M
