---@module favdir.ui.rendering.panels
---Panel rendering for favdir (left groups panel, right items panel)

local M = {}

local state_module = require("favdir.state")
local icons = require("favdir.ui.icons")
local sort_comparators = require("favdir.state.sort_comparators")
local constants = require("favdir.constants")
local tree = require("favdir.ui.tree")
local directory = require("favdir.ui.rendering.directory")
local interactions = require("favdir.ui.rendering.interactions")

-- Wire up the interaction handler to directory module
directory.set_item_interact_handler(interactions.on_item_interact)

-- ============================================================================
-- Panel Rendering
-- ============================================================================

---Render left panel (groups)
---@param mp_state MultiPanelState
---@return string[] lines
---@return table[] highlights
function M.render_left_panel(mp_state)
  local data = state_module.load_data()
  local ui_state = state_module.load_ui_state()
  local nodes = tree.build_tree(data, ui_state)

  local ContentBuilder = require("nvim-float.content")
  local cb = ContentBuilder.new()

  if #nodes == 0 then
    cb:muted("No groups. Press 'a' to add one.")
    -- Store and associate ContentBuilder for element tracking
    mp_state._groups_content_builder = cb
    mp_state:set_panel_content_builder(constants.PANEL.GROUPS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  for _, node in ipairs(nodes) do
    local indent = string.rep("  ", node.level)
    local icon

    if node.is_dir_link then
      -- Directory link: use folder icon
      icon = icons.get_base_icon("directory")
    elseif node.has_children then
      -- Group with children: use expand/collapse icon
      icon = node.is_expanded and icons.get_base_icon("expanded") or icons.get_base_icon("collapsed")
    else
      -- Leaf group: use leaf icon
      icon = icons.get_base_icon("leaf")
    end

    -- Check if this is the selected item (group or dir_link)
    local is_selected = false
    if node.is_dir_link then
      is_selected = (ui_state.last_selected_type == constants.SELECTION_TYPE.DIR_LINK and ui_state.last_selected_dir_link == node.dir_path)
    else
      is_selected = (ui_state.last_selected_type == constants.SELECTION_TYPE.GROUP and ui_state.last_selected_group == node.full_path)
        or (ui_state.last_selected_type == nil and ui_state.last_selected_group == node.full_path)
    end

    -- Build line with element tracking
    cb:spans({
      {
        text = indent .. icon .. " " .. node.name,
        style = is_selected and "emphasis" or nil,
        track = {
          name = node.full_path,
          type = "action",
          row_based = true,
          hover_style = "emphasis",
          data = {
            node = node,
            panel = constants.PANEL.GROUPS,
          },
          on_interact = function(element)
            interactions.on_group_interact(element, mp_state)
          end,
        },
      },
    })
  end

  -- Store and associate ContentBuilder for element tracking
  mp_state._groups_content_builder = cb
  mp_state:set_panel_content_builder(constants.PANEL.GROUPS, cb)

  return cb:build_lines(), cb:build_highlights()
end

---Render right panel (items in selected group or directory contents for dir_link)
---@param mp_state MultiPanelState
---@return string[] lines
---@return table[] highlights
function M.render_right_panel(mp_state)
  local ui_state = state_module.load_ui_state()
  local ContentBuilder = require("nvim-float.content")
  local cb = ContentBuilder.new()

  -- Check if we're in directory browse mode (from opening a directory item)
  if ui_state.is_browsing_directory and ui_state.browse_base_path then
    local base_path = ui_state.browse_base_path
    local current_path = ui_state.browse_current_path or base_path
    return directory.render_dir_link_contents(mp_state, cb, base_path, current_path)
  end

  -- Check if a dir_link is selected
  if ui_state.last_selected_type == constants.SELECTION_TYPE.DIR_LINK and ui_state.last_selected_dir_link then
    local base_path = ui_state.last_selected_dir_link
    local current_path = ui_state.dir_link_current_path or base_path
    return directory.render_dir_link_contents(mp_state, cb, base_path, current_path)
  end

  -- Otherwise, render group items (original behavior)
  -- Reset dir_link view flags since we're viewing regular group items
  mp_state._is_dir_link_view = false
  mp_state._dir_link_base_path = nil
  mp_state._dir_link_current_path = nil

  local data = state_module.load_data()
  local group_path = ui_state.last_selected_group

  if not group_path then
    cb:muted("← Select a group to view items")
    mp_state._items_content_builder = cb
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  local group = state_module.find_group(data, group_path)
  if not group then
    cb:muted("Group not found")
    mp_state._items_content_builder = cb
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  if #group.items == 0 then
    cb:muted("No items in this group.")
    cb:muted("Press 'a' to add current dir/file.")
    mp_state._items_content_builder = cb
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  -- Sort items based on right_sort_mode
  local items = vim.tbl_values(group.items)
  local sort_mode = ui_state.right_sort_mode or "custom"
  local sort_asc = ui_state.right_sort_asc ~= false -- default to true
  table.sort(items, sort_comparators.item_comparator(sort_mode, sort_asc))

  -- Store sorted items for operations that need index
  mp_state._sorted_items = items

  for idx, item in ipairs(items) do
    local icon, color
    if item.type == constants.ITEM_TYPE.DIR then
      icon = icons.get_base_icon("directory")
      color = icons.get_directory_color()
    else
      icon, color = icons.get_file_icon(item.path)
    end

    local name = vim.fn.fnamemodify(item.path, ':t')

    -- Shorten home directory
    local display_path = item.path
    local home = vim.fn.expand('~')
    if vim.startswith(display_path, home) then
      display_path = "~" .. display_path:sub(#home + 1)
    end

    local icon_hl = icons.get_icon_hl(color)

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
            index = idx,
            group_path = group_path,
            panel = constants.PANEL.ITEMS,
          },
          on_interact = function(element)
            interactions.on_item_interact(element, mp_state)
          end,
        },
      },
      { text = name, style = item.type == constants.ITEM_TYPE.DIR and "strong" or nil },
      { text = " ", style = "muted" },
      { text = display_path, style = "muted" },
    })
  end

  -- Store and associate ContentBuilder for element tracking
  mp_state._items_content_builder = cb
  mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)

  return cb:build_lines(), cb:build_highlights()
end

return M
