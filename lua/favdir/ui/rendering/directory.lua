---@module favdir.ui.rendering.directory
---Directory link contents rendering for favdir

local M = {}

local state_module = require("favdir.state")
local icons = require("favdir.ui.icons")
local sort_comparators = require("favdir.state.sort_comparators")
local constants = require("favdir.constants")

-- Forward declaration for interaction handler
local on_item_interact

---Set the item interaction handler (called by panels module to avoid circular deps)
---@param handler fun(element: TrackedElement, mp_state: MultiPanelState)
function M.set_item_interact_handler(handler)
  on_item_interact = handler
end

-- ============================================================================
-- Directory Link Contents Rendering
-- ============================================================================

---Render filesystem contents for a directory link
---@param mp_state MultiPanelState
---@param cb any ContentBuilder instance
---@param base_path string Base directory path (the dir_link's original path)
---@param current_path string Current browsing path (may be a subfolder)
---@return string[] lines
---@return table[] highlights
function M.render_dir_link_contents(mp_state, cb, base_path, current_path)
  -- Validate directory exists
  if vim.fn.isdirectory(current_path) ~= 1 then
    cb:muted("Directory not found:")
    cb:muted(current_path)
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  -- Store base path for navigation validation
  mp_state._dir_link_base_path = base_path
  mp_state._dir_link_current_path = current_path

  -- Check if we're in a subfolder (show "../" entry)
  local is_in_subfolder = vim.fn.fnamemodify(current_path, ':p') ~= vim.fn.fnamemodify(base_path, ':p')

  -- In browse mode (from group directory item), always show "../" as exit indicator
  local ui_state = state_module.load_ui_state()
  local show_parent_entry = is_in_subfolder or ui_state.is_browsing_directory

  -- Read directory contents
  local ok, entries = pcall(vim.fn.readdir, current_path)
  if not ok or not entries then
    cb:muted("Failed to read directory")
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  -- Build items list with type info
  local items = {}

  -- Add "../" entry if in subfolder OR in browse mode (as exit indicator)
  if show_parent_entry then
    table.insert(items, {
      name = "..",
      path = vim.fn.fnamemodify(current_path, ':h'),
      type = constants.ITEM_TYPE.PARENT,
    })
  end

  for _, entry in ipairs(entries) do
    local full_path = current_path .. "/" .. entry
    local is_dir = vim.fn.isdirectory(full_path) == 1
    table.insert(items, {
      name = entry,
      path = full_path,
      type = is_dir and constants.ITEM_TYPE.DIR or constants.ITEM_TYPE.FILE,
    })
  end

  -- Sort based on dir_sort_mode (parent ".." always first)
  local sort_mode = ui_state.dir_sort_mode or "type"
  local sort_asc = ui_state.dir_sort_asc ~= false -- default to true
  table.sort(items, sort_comparators.directory_comparator(sort_mode, sort_asc))

  -- Store for operations
  mp_state._sorted_items = items
  mp_state._is_dir_link_view = true

  if #entries == 0 and not show_parent_entry then
    cb:muted("Directory is empty")
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  for _, item in ipairs(items) do
    local icon, color
    if item.type == constants.ITEM_TYPE.PARENT then
      icon = icons.get_base_icon("collapsed")
      color = nil
    elseif item.type == constants.ITEM_TYPE.DIR then
      icon = icons.get_base_icon("directory")
      color = icons.get_directory_color()
    else
      icon, color = icons.get_file_icon(item.path)
    end

    local icon_hl = color and icons.get_icon_hl(color) or nil

    -- Build line with element tracking
    cb:spans({
      {
        text = icon .. " ",
        hl_group = icon_hl,
        track = {
          name = item.path,
          type = "action",
          row_based = true,
          hover_style = "emphasis",
          data = {
            item = item,
            panel = constants.PANEL.ITEMS,
            is_dir_link_view = true,
            base_path = base_path,
          },
          on_interact = function(element)
            if on_item_interact then
              on_item_interact(element, mp_state)
            end
          end,
        },
      },
      { text = item.name, style = (item.type == constants.ITEM_TYPE.DIR or item.type == constants.ITEM_TYPE.PARENT) and "strong" or nil },
    })
  end

  mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)

  return cb:build_lines(), cb:build_highlights()
end

return M
