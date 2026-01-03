---@module favdir.ui.rendering
---Tree building and panel rendering for favdir

local M = {}

local state_module = require("favdir.state")
local icons = require("favdir.ui.icons")

-- ============================================================================
-- Type Definitions
-- ============================================================================

---@class TreeNode
---@field name string Display name
---@field full_path string Full group path (e.g., "Work.Projects")
---@field level number Indentation level (0-based)
---@field is_expanded boolean Whether expanded
---@field has_children boolean Whether has child groups
---@field is_leaf boolean Whether this is a leaf group (no children)
---@field group FavdirGroup Reference to the group

-- ============================================================================
-- Tree Building
-- ============================================================================

---Build visible tree nodes from data
---@param data FavdirData
---@param ui_state FavdirUIState
---@return TreeNode[]
function M.build_tree(data, ui_state)
  local nodes = {}

  local function collect(groups, prefix, level)
    -- Sort by order
    local sorted = vim.tbl_values(groups)
    table.sort(sorted, function(a, b)
      return (a.order or 0) < (b.order or 0)
    end)

    for _, group in ipairs(sorted) do
      local path = prefix == "" and group.name or (prefix .. "." .. group.name)
      local has_children = group.children and #group.children > 0
      local is_expanded = state_module.is_expanded(ui_state, path)

      table.insert(nodes, {
        name = group.name,
        full_path = path,
        level = level,
        is_expanded = is_expanded,
        has_children = has_children,
        is_leaf = not has_children,
        group = group,
      })

      -- Recursively add children if expanded
      if has_children and is_expanded then
        collect(group.children, path, level + 1)
      end
    end
  end

  collect(data.groups, "", 0)
  return nodes
end

-- ============================================================================
-- Interaction Handlers (called from element tracking)
-- ============================================================================

---Handle group element interaction (Enter key) - only selects, doesn't toggle
---@param element TrackedElement
---@param mp_state MultiPanelState
function M.on_group_interact(element, mp_state)
  if not element or not element.data then return end

  local node = element.data.node
  if not node then return end

  -- Select this group (don't toggle - that's handled by 'o' key)
  local ui_state = state_module.load_ui_state()
  ui_state.last_selected_group = node.full_path
  state_module.save_ui_state(ui_state)

  -- Refresh both panels
  mp_state:render_panel("groups")
  mp_state:render_panel("items")
end

---Handle item element interaction (Enter key)
---@param element TrackedElement
---@param mp_state MultiPanelState
function M.on_item_interact(element, mp_state)
  if not element or not element.data then return end

  local item = element.data.item
  if not item then return end

  -- Close the UI first
  mp_state:close()

  if item.type == "dir" then
    vim.cmd.cd(item.path)
    vim.notify("Changed to: " .. item.path, vim.log.levels.INFO)
  else
    vim.cmd.edit(item.path)
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
  local data = state_module.load_data()
  local ui_state = state_module.load_ui_state()
  local nodes = M.build_tree(data, ui_state)

  local ContentBuilder = require("nvim-float.content")
  local cb = ContentBuilder.new()

  if #nodes == 0 then
    cb:muted("No groups. Press 'a' to add one.")
    -- Store and associate ContentBuilder for element tracking
    mp_state._groups_content_builder = cb
    mp_state:set_panel_content_builder("groups", cb)
    return cb:build_lines(), cb:build_highlights()
  end

  for _, node in ipairs(nodes) do
    local indent = string.rep("  ", node.level)
    local icon
    if node.has_children then
      icon = node.is_expanded and icons.get_base_icon("expanded") or icons.get_base_icon("collapsed")
    else
      icon = icons.get_base_icon("leaf")
    end

    -- Check if this is the selected group
    local is_selected = (ui_state.last_selected_group == node.full_path)

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
            panel = "groups",
          },
          on_interact = function(element)
            M.on_group_interact(element, mp_state)
          end,
        },
      },
    })
  end

  -- Store and associate ContentBuilder for element tracking
  mp_state._groups_content_builder = cb
  mp_state:set_panel_content_builder("groups", cb)

  return cb:build_lines(), cb:build_highlights()
end

---Render right panel (items in selected group)
---@param mp_state MultiPanelState
---@return string[] lines
---@return table[] highlights
function M.render_right_panel(mp_state)
  local ui_state = state_module.load_ui_state()
  -- Always load fresh data to ensure we see newly added items
  local data = state_module.load_data()

  local ContentBuilder = require("nvim-float.content")
  local cb = ContentBuilder.new()

  local group_path = ui_state.last_selected_group
  if not group_path then
    cb:muted("← Select a group to view items")
    -- Store and associate ContentBuilder for element tracking
    mp_state._items_content_builder = cb
    mp_state:set_panel_content_builder("items", cb)
    return cb:build_lines(), cb:build_highlights()
  end

  local group = state_module.find_group(data, group_path)
  if not group then
    cb:muted("Group not found")
    mp_state._items_content_builder = cb
    mp_state:set_panel_content_builder("items", cb)
    return cb:build_lines(), cb:build_highlights()
  end

  if #group.items == 0 then
    cb:muted("No items in this group.")
    cb:muted("Press 'a' to add current dir/file.")
    mp_state._items_content_builder = cb
    mp_state:set_panel_content_builder("items", cb)
    return cb:build_lines(), cb:build_highlights()
  end

  -- Sort items based on mode
  local items = vim.tbl_values(group.items)
  local sort_mode = ui_state.right_sort_mode or "custom"

  if sort_mode == "alpha" then
    table.sort(items, function(a, b)
      local name_a = vim.fn.fnamemodify(a.path, ':t'):lower()
      local name_b = vim.fn.fnamemodify(b.path, ':t'):lower()
      return name_a < name_b
    end)
  elseif sort_mode == "type" then
    table.sort(items, function(a, b)
      if a.type ~= b.type then
        return a.type == "dir"
      end
      local name_a = vim.fn.fnamemodify(a.path, ':t'):lower()
      local name_b = vim.fn.fnamemodify(b.path, ':t'):lower()
      return name_a < name_b
    end)
  else
    table.sort(items, function(a, b)
      return (a.order or 0) < (b.order or 0)
    end)
  end

  -- Store sorted items for operations that need index
  mp_state._sorted_items = items

  for idx, item in ipairs(items) do
    local icon, color
    if item.type == "dir" then
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
            panel = "items",
          },
          on_interact = function(element)
            M.on_item_interact(element, mp_state)
          end,
        },
      },
      { text = name, style = item.type == "dir" and "strong" or nil },
      { text = " ", style = "muted" },
      { text = display_path, style = "muted" },
    })
  end

  -- Store and associate ContentBuilder for element tracking
  mp_state._items_content_builder = cb
  mp_state:set_panel_content_builder("items", cb)

  return cb:build_lines(), cb:build_highlights()
end

return M
