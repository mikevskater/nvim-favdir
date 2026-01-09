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
---@field has_children boolean Whether has child groups or dir_links
---@field is_leaf boolean Whether this is a leaf (no children/dir_links)
---@field is_dir_link boolean Whether this is a directory link
---@field dir_path string? Filesystem path for dir_links
---@field group FavdirGroup? Reference to the group (nil for dir_links)
---@field dir_link FavdirDirLink? Reference to the dir_link (nil for groups)

-- ============================================================================
-- Tree Building
-- ============================================================================

---Build visible tree nodes from data
---@param data FavdirData
---@param ui_state FavdirUIState
---@return TreeNode[]
function M.build_tree(data, ui_state)
  local nodes = {}
  local left_sort_asc = ui_state.left_sort_asc ~= false -- default to true

  local function collect(groups, prefix, level)
    -- Sort by order
    local sorted = vim.tbl_values(groups)
    table.sort(sorted, function(a, b)
      local result = (a.order or 0) < (b.order or 0)
      if not left_sort_asc then
        return not result
      end
      return result
    end)

    for _, group in ipairs(sorted) do
      local path = prefix == "" and group.name or (prefix .. "." .. group.name)
      local has_children = (group.children and #group.children > 0)
        or (group.dir_links and #group.dir_links > 0)
      local is_expanded = state_module.is_expanded(ui_state, path)

      table.insert(nodes, {
        name = group.name,
        full_path = path,
        level = level,
        is_expanded = is_expanded,
        has_children = has_children,
        is_leaf = not has_children,
        is_dir_link = false,
        dir_path = nil,
        group = group,
        dir_link = nil,
      })

      -- Recursively add children and dir_links if expanded
      if is_expanded then
        -- Collect children and dir_links, sort together by order
        local child_items = {}

        if group.children then
          for _, child in ipairs(group.children) do
            table.insert(child_items, { type = "group", item = child, order = child.order or 0 })
          end
        end

        if group.dir_links then
          for _, link in ipairs(group.dir_links) do
            table.insert(child_items, { type = "dir_link", item = link, order = link.order or 0 })
          end
        end

        -- Sort by order
        table.sort(child_items, function(a, b)
          local result = a.order < b.order
          if not left_sort_asc then
            return not result
          end
          return result
        end)

        for _, child_item in ipairs(child_items) do
          if child_item.type == "group" then
            -- Recursively collect this group
            collect({ child_item.item }, path, level + 1)
          else
            -- Add dir_link node
            local link = child_item.item
            local link_path = path .. "." .. link.name
            table.insert(nodes, {
              name = link.name,
              full_path = link_path,
              level = level + 1,
              is_expanded = false,
              has_children = false,
              is_leaf = true,
              is_dir_link = true,
              dir_path = link.path,
              group = nil,
              dir_link = link,
            })
          end
        end
      end
    end
  end

  collect(data.groups, "", 0)
  return nodes
end

-- ============================================================================
-- Interaction Handlers (called from element tracking)
-- ============================================================================

---Handle group/dir_link element interaction (Enter key) - only selects, doesn't toggle
---@param element TrackedElement
---@param mp_state MultiPanelState
function M.on_group_interact(element, mp_state)
  if not element or not element.data then return end

  local node = element.data.node
  if not node then return end

  local ui_state = state_module.load_ui_state()

  -- Reset browse state when selecting anything on left panel
  ui_state.is_browsing_directory = false
  ui_state.browse_base_path = nil
  ui_state.browse_current_path = nil

  if node.is_dir_link then
    -- Select this dir_link (reset navigation to base path)
    ui_state.last_selected_type = "dir_link"
    ui_state.last_selected_dir_link = node.dir_path
    ui_state.dir_link_current_path = nil -- Reset to base path
    ui_state.last_selected_group = nil
  else
    -- Select this group (don't toggle - that's handled by 'o' key)
    ui_state.last_selected_type = "group"
    ui_state.last_selected_group = node.full_path
    ui_state.last_selected_dir_link = nil
    ui_state.dir_link_current_path = nil
  end

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

  -- Handle "../" parent entry - trigger go up navigation instead of opening
  if item.type == "parent" then
    local navigation = require("favdir.ui.handlers.navigation")
    navigation.handle_go_up(mp_state)
    return
  end

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
      is_selected = (ui_state.last_selected_type == "dir_link" and ui_state.last_selected_dir_link == node.dir_path)
    else
      is_selected = (ui_state.last_selected_type == "group" and ui_state.last_selected_group == node.full_path)
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
    return M.render_dir_link_contents(mp_state, cb, base_path, current_path)
  end

  -- Check if a dir_link is selected
  if ui_state.last_selected_type == "dir_link" and ui_state.last_selected_dir_link then
    local base_path = ui_state.last_selected_dir_link
    local current_path = ui_state.dir_link_current_path or base_path
    return M.render_dir_link_contents(mp_state, cb, base_path, current_path)
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

  -- Sort items based on right_sort_mode
  local items = vim.tbl_values(group.items)
  local sort_mode = ui_state.right_sort_mode or "custom"
  local sort_asc = ui_state.right_sort_asc ~= false -- default to true
  table.sort(items, function(a, b)
    local result
    if sort_mode == "custom" then
      -- Use order field for manual sorting
      result = (a.order or 0) < (b.order or 0)
    elseif sort_mode == "name" then
      -- Alphabetical by filename
      local name_a = vim.fn.fnamemodify(a.path, ':t'):lower()
      local name_b = vim.fn.fnamemodify(b.path, ':t'):lower()
      result = name_a < name_b
    elseif sort_mode == "created" then
      -- By creation time (newest first by default)
      local stat_a = vim.loop.fs_stat(a.path)
      local stat_b = vim.loop.fs_stat(b.path)
      local ctime_a = stat_a and stat_a.birthtime and stat_a.birthtime.sec or 0
      local ctime_b = stat_b and stat_b.birthtime and stat_b.birthtime.sec or 0
      result = ctime_a > ctime_b
    elseif sort_mode == "modified" then
      -- By modification time (newest first by default)
      local stat_a = vim.loop.fs_stat(a.path)
      local stat_b = vim.loop.fs_stat(b.path)
      local mtime_a = stat_a and stat_a.mtime and stat_a.mtime.sec or 0
      local mtime_b = stat_b and stat_b.mtime and stat_b.mtime.sec or 0
      result = mtime_a > mtime_b
    elseif sort_mode == "size" then
      -- By size (largest first by default, dirs treated as 0)
      local stat_a = vim.loop.fs_stat(a.path)
      local stat_b = vim.loop.fs_stat(b.path)
      local size_a = (stat_a and a.type == "file") and stat_a.size or 0
      local size_b = (stat_b and b.type == "file") and stat_b.size or 0
      result = size_a > size_b
    else
      -- "type": directories first, then files, alphabetically within each
      if a.type ~= b.type then
        result = a.type == "dir"
      else
        local name_a = vim.fn.fnamemodify(a.path, ':t'):lower()
        local name_b = vim.fn.fnamemodify(b.path, ':t'):lower()
        result = name_a < name_b
      end
    end

    -- Reverse if descending
    if not sort_asc then
      return not result
    end
    return result
  end)

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
    mp_state._items_content_builder = cb
    mp_state:set_panel_content_builder("items", cb)
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
    mp_state._items_content_builder = cb
    mp_state:set_panel_content_builder("items", cb)
    return cb:build_lines(), cb:build_highlights()
  end

  -- Build items list with type info
  local items = {}

  -- Add "../" entry if in subfolder OR in browse mode (as exit indicator)
  if show_parent_entry then
    table.insert(items, {
      name = "..",
      path = vim.fn.fnamemodify(current_path, ':h'),
      type = "parent",
    })
  end

  for _, entry in ipairs(entries) do
    local full_path = current_path .. "/" .. entry
    local is_dir = vim.fn.isdirectory(full_path) == 1
    table.insert(items, {
      name = entry,
      path = full_path,
      type = is_dir and "dir" or "file",
    })
  end

  -- Sort based on dir_sort_mode (parent ".." always first)
  local sort_mode = ui_state.dir_sort_mode or "type"
  local sort_asc = ui_state.dir_sort_asc ~= false -- default to true
  table.sort(items, function(a, b)
    -- Parent entry always comes first
    if a.type == "parent" then return true end
    if b.type == "parent" then return false end

    local result
    if sort_mode == "name" then
      -- Alphabetical by name
      result = a.name:lower() < b.name:lower()
    elseif sort_mode == "created" then
      -- By creation time (newest first by default)
      local stat_a = vim.loop.fs_stat(a.path)
      local stat_b = vim.loop.fs_stat(b.path)
      local ctime_a = stat_a and stat_a.birthtime and stat_a.birthtime.sec or 0
      local ctime_b = stat_b and stat_b.birthtime and stat_b.birthtime.sec or 0
      result = ctime_a > ctime_b
    elseif sort_mode == "modified" then
      -- By modification time (newest first by default)
      local stat_a = vim.loop.fs_stat(a.path)
      local stat_b = vim.loop.fs_stat(b.path)
      local mtime_a = stat_a and stat_a.mtime and stat_a.mtime.sec or 0
      local mtime_b = stat_b and stat_b.mtime and stat_b.mtime.sec or 0
      result = mtime_a > mtime_b
    elseif sort_mode == "size" then
      -- By size (largest first by default, dirs treated as 0)
      local stat_a = vim.loop.fs_stat(a.path)
      local stat_b = vim.loop.fs_stat(b.path)
      local size_a = (stat_a and a.type == "file") and stat_a.size or 0
      local size_b = (stat_b and b.type == "file") and stat_b.size or 0
      result = size_a > size_b
    else
      -- "type" (default): directories first, then files, alphabetically within each
      if a.type ~= b.type then
        result = a.type == "dir"
      else
        result = a.name:lower() < b.name:lower()
      end
    end

    -- Reverse if descending
    if not sort_asc then
      return not result
    end
    return result
  end)

  -- Store for operations
  mp_state._sorted_items = items
  mp_state._is_dir_link_view = true

  if #entries == 0 and not show_parent_entry then
    cb:muted("Directory is empty")
    mp_state._items_content_builder = cb
    mp_state:set_panel_content_builder("items", cb)
    return cb:build_lines(), cb:build_highlights()
  end

  for _, item in ipairs(items) do
    local icon, color
    if item.type == "parent" then
      icon = icons.get_base_icon("collapsed")
      color = nil
    elseif item.type == "dir" then
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
            panel = "items",
            is_dir_link_view = true,
            base_path = base_path,
          },
          on_interact = function(element)
            M.on_item_interact(element, mp_state)
          end,
        },
      },
      { text = item.name, style = (item.type == "dir" or item.type == "parent") and "strong" or nil },
    })
  end

  mp_state._items_content_builder = cb
  mp_state:set_panel_content_builder("items", cb)

  return cb:build_lines(), cb:build_highlights()
end

return M
