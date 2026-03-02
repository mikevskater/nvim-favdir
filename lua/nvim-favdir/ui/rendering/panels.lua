---@module favdir.ui.rendering.panels
---Panel rendering for favdir (left groups panel, right items panel)

local M = {}

local data_module = require("nvim-favdir.state.data")
local groups_module = require("nvim-favdir.state.groups")
local icons = require("nvim-favdir.ui.icons")
local sort_comparators = require("nvim-favdir.state.sort_comparators")
local constants = require("nvim-favdir.constants")
local tree = require("nvim-favdir.ui.tree")
local directory = require("nvim-favdir.ui.rendering.directory")
local interactions = require("nvim-favdir.ui.rendering.interactions")

-- Wire up the interaction handler to directory module
directory.set_item_interact_handler(interactions.on_item_interact)

-- ============================================================================
-- Panel Title Helpers
-- ============================================================================

---Get sort mode display string
---@param mode string Sort mode
---@param ascending boolean
---@return string
local function sort_indicator(mode, ascending)
  if mode == "custom" then return "" end
  local arrow = ascending and "^" or "v"
  return " [" .. mode .. " " .. arrow .. "]"
end

---Update a panel's floating window title
---@param mp_state MultiPanelState
---@param panel_name string
---@param title string
local function set_panel_title(mp_state, panel_name, title)
  local buf = mp_state:get_panel_buffer(panel_name)
  if not buf then return end
  local wins = vim.fn.win_findbuf(buf)
  if #wins > 0 then
    pcall(vim.api.nvim_win_set_config, wins[1], { title = title })
  end
end

-- ============================================================================
-- Panel Rendering
-- ============================================================================

---Render left panel (groups)
---@param mp_state MultiPanelState
---@return string[] lines
---@return table[] highlights
function M.render_left_panel(mp_state)
  local data = data_module.load_data()
  local ui_state = data_module.load_ui_state()
  local nodes = tree.build_tree(data, ui_state)

  local ContentBuilder = require("nvim-float.content")
  local cb = ContentBuilder.new()

  if #nodes == 0 then
    cb:muted("No groups. Press 'a' to add one.")
    mp_state:set_panel_content_builder(constants.PANEL.GROUPS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  for _, node in ipairs(nodes) do
    local indent = string.rep("  ", node.level)
    local group = node.group

    -- Get icon and color (respects custom icon/color on the group)
    local icon, icon_color = icons.get_group_icon(
      group,
      node.is_expanded,
      node.has_children,
      node.is_dir_link
    )

    -- Check if this is the selected item (group or dir_link)
    local is_selected = false
    if node.is_dir_link then
      is_selected = (ui_state.last_selected_type == constants.SELECTION_TYPE.DIR_LINK and ui_state.last_selected_dir_link == node.dir_path)
    else
      is_selected = (ui_state.last_selected_type == constants.SELECTION_TYPE.GROUP and ui_state.last_selected_group == node.full_path)
        or (ui_state.last_selected_type == nil and ui_state.last_selected_group == node.full_path)
    end

    -- Determine highlight groups for icon and name
    local icon_hl = (not is_selected and icon_color) and icons.get_icon_hl(icon_color) or nil
    local name_color = not node.is_dir_link and group and group.name_color or nil
    local name_hl = (not is_selected and name_color) and icons.get_icon_hl(name_color) or nil

    -- Build line with separate icon and name spans for custom coloring
    cb:spans({
      {
        text = indent .. icon .. " ",
        style = is_selected and "emphasis" or nil,
        hl_group = (not is_selected) and icon_hl or nil,
      },
      {
        text = node.name,
        style = is_selected and "emphasis" or nil,
        hl_group = (not is_selected) and name_hl or nil,
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

  mp_state:set_panel_content_builder(constants.PANEL.GROUPS, cb)

  -- Update left panel title with sort indicator
  local left_mode = ui_state.left_sort_mode or "custom"
  local left_asc = ui_state.left_sort_asc ~= false
  set_panel_title(mp_state, constants.PANEL.GROUPS, " Groups" .. sort_indicator(left_mode, left_asc) .. " ")

  return cb:build_lines(), cb:build_highlights()
end

---Render right panel (items in selected group or directory contents for dir_link)
---@param mp_state MultiPanelState
---@return string[] lines
---@return table[] highlights
function M.render_right_panel(mp_state)
  local ui_state = data_module.load_ui_state()
  local ContentBuilder = require("nvim-float.content")
  local cb = ContentBuilder.new()

  -- Inline filter input at top of panel
  cb:embedded_input("filter", {
    tab_stop = false,
    placeholder = "/ filter...",
    value = mp_state._favdir.active_filter or "",
    width = 25,
    on_submit = function(_, v)
      mp_state._favdir.active_filter = (v ~= "") and v or nil
      mp_state:render_panel(constants.PANEL.ITEMS)
    end,
  })

  local filter_str = ""

  -- Check if we're in directory browse mode (from opening a directory item)
  if ui_state.is_browsing_directory and ui_state.browse_base_path then
    local base_path = ui_state.browse_base_path
    local current_path = ui_state.browse_current_path or base_path
    local dir_mode = ui_state.dir_sort_mode or "type"
    local dir_asc = ui_state.dir_sort_asc ~= false
    local dir_name = vim.fn.fnamemodify(current_path, ':t')
    set_panel_title(mp_state, constants.PANEL.ITEMS,
      " " .. dir_name .. sort_indicator(dir_mode, dir_asc) .. filter_str .. " ")
    directory.render_dir_link_contents(mp_state, cb, base_path, current_path)
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  -- Check if a dir_link is selected
  if ui_state.last_selected_type == constants.SELECTION_TYPE.DIR_LINK and ui_state.last_selected_dir_link then
    local base_path = ui_state.last_selected_dir_link
    local current_path = ui_state.dir_link_current_path or base_path
    local dir_mode = ui_state.dir_sort_mode or "type"
    local dir_asc = ui_state.dir_sort_asc ~= false
    local dir_name = vim.fn.fnamemodify(current_path, ':t')
    set_panel_title(mp_state, constants.PANEL.ITEMS,
      " " .. dir_name .. sort_indicator(dir_mode, dir_asc) .. filter_str .. " ")
    directory.render_dir_link_contents(mp_state, cb, base_path, current_path)
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  -- Otherwise, render group items (original behavior)
  -- Reset dir_link view flags since we're viewing regular group items
  mp_state._favdir.is_dir_link_view = false
  mp_state._favdir.dir_link_base_path = nil
  mp_state._favdir.dir_link_current_path = nil
  mp_state._favdir.sorted_items = {}

  local data = data_module.load_data()
  local group_path = ui_state.last_selected_group

  if not group_path then
    set_panel_title(mp_state, constants.PANEL.ITEMS, " Items ")
    cb:muted("← Select a group to view items")
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  local group = groups_module.find_group(data, group_path)
  if not group then
    cb:muted("Group not found")
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  if #group.items == 0 then
    cb:muted("No items in this group.")
    cb:muted("Press 'a' to add current dir/file.")
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  -- Sort items based on right_sort_mode
  local items = vim.tbl_values(group.items)
  local sort_mode = ui_state.right_sort_mode or "custom"
  local sort_asc = ui_state.right_sort_asc ~= false -- default to true
  table.sort(items, sort_comparators.item_comparator(sort_mode, sort_asc))

  -- Apply filter if active
  local filter = mp_state._favdir.active_filter
  if filter then
    local filtered = {}
    local filter_lower = filter:lower()
    for _, item in ipairs(items) do
      local path_for_name = item.path:gsub("[/\\]+$", "")
      local name = (item.display_name or vim.fn.fnamemodify(path_for_name, ':t')):lower()
      if name:find(filter_lower, 1, true) then
        table.insert(filtered, item)
      end
    end
    if #filtered == 0 then
      cb:muted("No matches for '/" .. filter .. "'")
      cb:muted("Press '/' to change or clear filter.")
      mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
      -- Still update title with filter indicator
      local group_display = group.display_name or group.name
      set_panel_title(mp_state, constants.PANEL.ITEMS,
        " " .. group_display .. sort_indicator(sort_mode, sort_asc) .. filter_str .. " ")
      return cb:build_lines(), cb:build_highlights()
    end
    items = filtered
  end

  -- Store sorted (and filtered) items for operations that need index
  mp_state._favdir.sorted_items = items

  for idx, item in ipairs(items) do
    local icon, color
    if item.type == constants.ITEM_TYPE.DIR then
      icon = icons.get_base_icon("directory")
      color = icons.get_directory_color()
    else
      icon, color = icons.get_file_icon(item.path)
    end

    -- Get name - use display_name (nickname) if set, otherwise filename
    local path_for_name = item.path:gsub("[/\\]+$", "")  -- Remove trailing slashes
    local name = item.display_name or vim.fn.fnamemodify(path_for_name, ':t')

    -- Check if path still exists
    local path_exists
    if item.type == constants.ITEM_TYPE.DIR then
      path_exists = vim.fn.isdirectory(item.path) == 1
    else
      path_exists = vim.fn.filereadable(item.path) == 1
    end

    -- Shorten home directory
    local display_path = item.path
    local home = vim.fn.expand('~')
    if vim.startswith(display_path, home) then
      display_path = "~" .. display_path:sub(#home + 1)
    end

    local icon_hl = icons.get_icon_hl(color)

    -- Build spans list
    local spans = {
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
    }

    -- Show warning icon for missing paths
    if not path_exists then
      table.insert(spans, { text = " " .. icons.get_base_icon("warning"), hl_group = "WarningMsg" })
    end

    table.insert(spans, { text = " ", style = "muted" })
    table.insert(spans, { text = display_path, style = "muted" })

    -- Build line with element tracking
    cb:spans(spans)
  end

  mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)

  -- Update right panel title with group name, sort indicator, and filter
  local group_display = group.display_name or group.name
  set_panel_title(mp_state, constants.PANEL.ITEMS,
    " " .. group_display .. sort_indicator(sort_mode, sort_asc) .. filter_str .. " ")

  return cb:build_lines(), cb:build_highlights()
end

return M
