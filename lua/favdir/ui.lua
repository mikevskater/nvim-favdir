---@class FavdirUI
---Multi-panel UI for managing favorite directories
---@module favdir.ui

local M = {}

local state_module = require("favdir.state")

---@type MultiPanelState?
local panel_state = nil

-- ============================================================================
-- Icons (using nerd font icons with Unicode codepoints)
-- ============================================================================

-- Helper to convert codepoint to UTF-8 character
local function nf(codepoint)
  return vim.fn.nr2char(codepoint)
end

local icons = {
  expanded = "▼",
  collapsed = "▶",
  leaf = " ",
  directory = nf(0xF07B),  -- nf-fa-folder
  file = nf(0xF15B),       -- nf-fa-file
  file_default = nf(0xF15B),  -- nf-fa-file
}

-- File extension to icon mapping (common types)
-- Codepoints from nvim-web-devicons / Nerd Fonts
local file_icons = {
  -- Lua
  lua = nf(0xE620),        -- nf-seti-lua

  -- Python
  py = nf(0xE73C),         -- nf-dev-python
  python = nf(0xE73C),

  -- JavaScript/TypeScript
  js = nf(0xE74E),         -- nf-dev-javascript
  mjs = nf(0xE74E),
  cjs = nf(0xE74E),
  ts = nf(0xE628),         -- nf-seti-typescript
  mts = nf(0xE628),
  jsx = nf(0xE7BA),        -- nf-dev-react
  tsx = nf(0xE7BA),

  -- Web
  json = nf(0xE60B),       -- nf-seti-json
  html = nf(0xE736),       -- nf-dev-html5
  htm = nf(0xE736),
  css = nf(0xE749),        -- nf-dev-css3
  scss = nf(0xE749),
  sass = nf(0xE749),
  less = nf(0xE749),

  -- Markdown/Docs
  md = nf(0xE609),         -- nf-seti-markdown
  markdown = nf(0xE609),
  mdx = nf(0xE609),
  txt = nf(0xF15C),        -- nf-fa-file_text

  -- Config/Data
  yaml = nf(0xE6A8),       -- nf-seti-yaml
  yml = nf(0xE6A8),
  toml = nf(0xE615),       -- nf-seti-config
  xml = nf(0xE619),        -- nf-seti-xml
  ini = nf(0xE615),
  conf = nf(0xE615),
  config = nf(0xE615),

  -- Shell
  sh = nf(0xF489),         -- nf-oct-terminal
  bash = nf(0xF489),
  zsh = nf(0xF489),
  fish = nf(0xF489),
  ps1 = nf(0xF489),
  bat = nf(0xF489),
  cmd = nf(0xF489),

  -- Systems languages
  c = nf(0xE61E),          -- nf-custom-c
  h = nf(0xE61E),
  cpp = nf(0xE61D),        -- nf-custom-cpp
  cc = nf(0xE61D),
  cxx = nf(0xE61D),
  hpp = nf(0xE61D),
  hxx = nf(0xE61D),
  rs = nf(0xE7A8),         -- nf-dev-rust
  go = nf(0xE626),         -- nf-seti-go

  -- JVM
  java = nf(0xE738),       -- nf-dev-java
  kt = nf(0xE634),         -- nf-seti-kotlin
  kts = nf(0xE634),
  scala = nf(0xE737),      -- nf-dev-scala
  groovy = nf(0xE775),     -- nf-dev-groovy

  -- Ruby/PHP
  rb = nf(0xE739),         -- nf-dev-ruby
  ruby = nf(0xE739),
  php = nf(0xE73D),        -- nf-dev-php

  -- .NET
  cs = nf(0xF81A),         -- nf-md-language_csharp
  fs = nf(0xE7A7),         -- nf-dev-fsharp
  vb = nf(0xF81A),

  -- Database
  sql = nf(0xE706),        -- nf-dev-database

  -- Vim/Editor
  vim = nf(0xE62B),        -- nf-seti-vim
  nvim = nf(0xE62B),

  -- Git
  git = nf(0xE702),        -- nf-dev-git
  gitignore = nf(0xE702),
  gitattributes = nf(0xE702),
  gitmodules = nf(0xE702),

  -- Docker
  dockerfile = nf(0xE7B0), -- nf-dev-docker
  docker = nf(0xE7B0),

  -- Build
  makefile = nf(0xE779),   -- nf-dev-gnu
  cmake = nf(0xE615),
  rake = nf(0xE739),

  -- Images
  png = nf(0xF1C5),        -- nf-fa-file_image
  jpg = nf(0xF1C5),
  jpeg = nf(0xF1C5),
  gif = nf(0xF1C5),
  svg = nf(0xF1C5),
  ico = nf(0xF1C5),
  webp = nf(0xF1C5),

  -- Archives
  zip = nf(0xF1C6),        -- nf-fa-file_archive
  tar = nf(0xF1C6),
  gz = nf(0xF1C6),
  rar = nf(0xF1C6),
  ["7z"] = nf(0xF1C6),

  -- Lock files
  lock = nf(0xF023),       -- nf-fa-lock
}

---Get icon for a file extension
---@param path string
---@return string
local function get_file_icon(path)
  local name = vim.fn.fnamemodify(path, ':t'):lower()
  local ext = vim.fn.fnamemodify(path, ':e'):lower()

  -- Check full filename first (for dotfiles)
  if file_icons[name] then
    return file_icons[name]
  end

  -- Check extension
  if file_icons[ext] then
    return file_icons[ext]
  end

  return icons.file_default
end

-- ============================================================================
-- Tree Building
-- ============================================================================

---@class TreeNode
---@field name string Display name
---@field full_path string Full group path (e.g., "Work.Projects")
---@field level number Indentation level (0-based)
---@field is_expanded boolean Whether expanded
---@field has_children boolean Whether has child groups
---@field is_leaf boolean Whether this is a leaf group (no children)
---@field group FavdirGroup Reference to the group

---Build visible tree nodes from data
---@param data FavdirData
---@param ui_state FavdirUIState
---@return TreeNode[]
local function build_tree(data, ui_state)
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

---Find tree node at line number (1-based)
---@param nodes TreeNode[]
---@param line number 1-based line number
---@return TreeNode?
local function get_node_at_line(nodes, line)
  if line < 1 or line > #nodes then
    return nil
  end
  return nodes[line]
end

-- ============================================================================
-- Content Rendering
-- ============================================================================

---Render left panel (groups)
---@param mp_state MultiPanelState
---@return string[] lines
---@return table[] highlights
local function render_left_panel(mp_state)
  local data = state_module.load_data()
  local ui_state = state_module.load_ui_state()
  local nodes = build_tree(data, ui_state)

  -- Store nodes in state for reference
  mp_state.data = mp_state.data or {}
  mp_state.data.tree_nodes = nodes
  mp_state.data.main_data = data
  mp_state.data.ui_state = ui_state

  local ContentBuilder = require("nvim-float.content_builder")
  local cb = ContentBuilder.new()

  if #nodes == 0 then
    cb:muted("No groups. Press 'a' to add one.")
    local lines = cb:build_lines()
    local highlights = cb:build_highlights()
    return lines, highlights
  end

  for _, node in ipairs(nodes) do
    local indent = string.rep("  ", node.level)
    local icon
    if node.has_children then
      icon = node.is_expanded and icons.expanded or icons.collapsed
    else
      icon = icons.leaf
    end

    -- Check if this is the selected group
    local is_selected = (ui_state.last_selected_group == node.full_path)

    if is_selected then
      cb:spans({
        { text = indent },
        { text = icon .. " ", style = "muted" },
        { text = node.name, style = "emphasis" },
      })
    else
      cb:spans({
        { text = indent },
        { text = icon .. " ", style = "muted" },
        { text = node.name },
      })
    end
  end

  local lines = cb:build_lines()
  local highlights = cb:build_highlights()
  return lines, highlights
end

---Render right panel (items in selected group)
---@param mp_state MultiPanelState
---@return string[] lines
---@return table[] highlights
local function render_right_panel(mp_state)
  local ui_state = state_module.load_ui_state()
  local data = mp_state.data and mp_state.data.main_data or state_module.load_data()

  local ContentBuilder = require("nvim-float.content_builder")
  local cb = ContentBuilder.new()

  local group_path = ui_state.last_selected_group
  if not group_path then
    cb:muted("← Select a group to view items")
    local lines = cb:build_lines()
    local highlights = cb:build_highlights()
    return lines, highlights
  end

  local group = state_module.find_group(data, group_path)
  if not group then
    cb:muted("Group not found")
    local lines = cb:build_lines()
    local highlights = cb:build_highlights()
    return lines, highlights
  end

  -- Store items for reference
  mp_state.data = mp_state.data or {}
  mp_state.data.current_items = group.items

  if #group.items == 0 then
    cb:muted("No items in this group.")
    cb:muted("Press 'a' to add current dir/file.")
    local lines = cb:build_lines()
    local highlights = cb:build_highlights()
    return lines, highlights
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

  for _, item in ipairs(items) do
    local icon = item.type == "dir" and icons.directory or get_file_icon(item.path)
    local name = vim.fn.fnamemodify(item.path, ':t')

    -- Shorten home directory
    local display_path = item.path
    local home = vim.fn.expand('~')
    if vim.startswith(display_path, home) then
      display_path = "~" .. display_path:sub(#home + 1)
    end

    if item.type == "dir" then
      cb:spans({
        { text = icon .. " ", style = "keyword" },
        { text = name, style = "strong" },
        { text = " ", style = "muted" },
        { text = display_path, style = "muted" },
      })
    else
      cb:spans({
        { text = icon .. " ", style = "string" },
        { text = name },
        { text = " ", style = "muted" },
        { text = display_path, style = "muted" },
      })
    end
  end

  local lines = cb:build_lines()
  local highlights = cb:build_highlights()
  return lines, highlights
end

-- ============================================================================
-- Keymap Handlers
-- ============================================================================

---Handle Enter key
---@param mp_state MultiPanelState
local function handle_enter(mp_state)
  local focused = mp_state.focused_panel
  local ui_state = state_module.load_ui_state()

  if focused == "groups" then
    -- Left panel: toggle expand or select group
    local row = mp_state:get_cursor("groups")
    local nodes = mp_state.data and mp_state.data.tree_nodes or {}
    local node = get_node_at_line(nodes, row)

    if not node then return end

    if node.has_children then
      -- Toggle expansion
      state_module.toggle_expanded(node.full_path)
    end

    -- Select this group
    ui_state.last_selected_group = node.full_path
    state_module.save_ui_state(ui_state)

    -- Refresh both panels
    mp_state:render_panel("groups")
    mp_state:render_panel("items")
  else
    -- Right panel: open directory or file
    local row = mp_state:get_cursor("items")
    local items = mp_state.data and mp_state.data.current_items or {}

    if row < 1 or row > #items then return end

    local item = items[row]
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
end

---Handle Add key
---@param mp_state MultiPanelState
local function handle_add(mp_state)
  local focused = mp_state.focused_panel

  if focused == "groups" then
    -- Add child group
    local row = mp_state:get_cursor("groups")
    local nodes = mp_state.data and mp_state.data.tree_nodes or {}
    local node = get_node_at_line(nodes, row)

    local parent_path = node and node.full_path or ""

    vim.ui.input({ prompt = "New group name: " }, function(name)
      if name and name ~= "" then
        local ok, err = state_module.add_group(parent_path, name)
        if ok then
          -- Expand parent to show new child
          if parent_path ~= "" then
            local ui_state = state_module.load_ui_state()
            if not state_module.is_expanded(ui_state, parent_path) then
              state_module.toggle_expanded(parent_path)
            end
          end
          mp_state:render_panel("groups")
        else
          vim.notify(err or "Failed to add group", vim.log.levels.ERROR)
        end
      end
    end)
  else
    -- Add item to current group
    local ui_state = state_module.load_ui_state()
    local group_path = ui_state.last_selected_group

    if not group_path then
      vim.notify("Select a group first", vim.log.levels.WARN)
      return
    end

    vim.ui.select(
      { "Current directory", "Current file", "Enter path..." },
      { prompt = "Add to " .. group_path .. ":" },
      function(choice)
        if not choice then return end

        local path
        if choice == "Current directory" then
          path = vim.fn.getcwd()
        elseif choice == "Current file" then
          path = vim.fn.expand('%:p')
          if path == "" then
            vim.notify("No file in current buffer", vim.log.levels.WARN)
            return
          end
        else
          vim.ui.input({ prompt = "Path: ", completion = "file" }, function(input)
            if input and input ~= "" then
              local ok, err = state_module.add_item(group_path, input)
              if ok then
                mp_state:render_panel("items")
              else
                vim.notify(err or "Failed to add item", vim.log.levels.ERROR)
              end
            end
          end)
          return
        end

        local ok, err = state_module.add_item(group_path, path)
        if ok then
          mp_state:render_panel("items")
        else
          vim.notify(err or "Failed to add item", vim.log.levels.ERROR)
        end
      end
    )
  end
end

---Handle Delete key
---@param mp_state MultiPanelState
local function handle_delete(mp_state)
  local focused = mp_state.focused_panel

  if focused == "groups" then
    local row = mp_state:get_cursor("groups")
    local nodes = mp_state.data and mp_state.data.tree_nodes or {}
    local node = get_node_at_line(nodes, row)

    if not node then return end

    vim.ui.select({ "Yes", "No" }, {
      prompt = "Delete group '" .. node.name .. "'?",
    }, function(choice)
      if choice == "Yes" then
        local ok, err = state_module.remove_group(node.full_path)
        if ok then
          mp_state:render_panel("groups")
          mp_state:render_panel("items")
        else
          vim.notify(err or "Failed to delete group", vim.log.levels.ERROR)
        end
      end
    end)
  else
    local ui_state = state_module.load_ui_state()
    local group_path = ui_state.last_selected_group
    if not group_path then return end

    local row = mp_state:get_cursor("items")
    local items = mp_state.data and mp_state.data.current_items or {}

    if row < 1 or row > #items then return end

    local item = items[row]
    local name = vim.fn.fnamemodify(item.path, ':t')

    vim.ui.select({ "Yes", "No" }, {
      prompt = "Remove '" .. name .. "' from group?",
    }, function(choice)
      if choice == "Yes" then
        local ok, err = state_module.remove_item(group_path, row)
        if ok then
          mp_state:render_panel("items")
        else
          vim.notify(err or "Failed to remove item", vim.log.levels.ERROR)
        end
      end
    end)
  end
end

---Handle Rename key
---@param mp_state MultiPanelState
local function handle_rename(mp_state)
  local focused = mp_state.focused_panel

  if focused == "groups" then
    local row = mp_state:get_cursor("groups")
    local nodes = mp_state.data and mp_state.data.tree_nodes or {}
    local node = get_node_at_line(nodes, row)

    if not node then return end

    vim.ui.input({
      prompt = "New name: ",
      default = node.name,
    }, function(new_name)
      if new_name and new_name ~= "" and new_name ~= node.name then
        local ok, err = state_module.rename_group(node.full_path, new_name)
        if ok then
          mp_state:render_panel("groups")
        else
          vim.notify(err or "Failed to rename group", vim.log.levels.ERROR)
        end
      end
    end)
  else
    vim.notify("Cannot rename items (use 'd' to remove and 'a' to add)", vim.log.levels.INFO)
  end
end

---Handle Move key (for items)
---@param mp_state MultiPanelState
local function handle_move(mp_state)
  local focused = mp_state.focused_panel

  if focused ~= "items" then
    vim.notify("Move only works for items", vim.log.levels.INFO)
    return
  end

  local ui_state = state_module.load_ui_state()
  local from_group = ui_state.last_selected_group
  if not from_group then return end

  local row = mp_state:get_cursor("items")
  local items = mp_state.data and mp_state.data.current_items or {}

  if row < 1 or row > #items then return end

  local groups = state_module.get_group_list()
  -- Filter out current group
  groups = vim.tbl_filter(function(g)
    return g ~= from_group
  end, groups)

  if #groups == 0 then
    vim.notify("No other groups to move to", vim.log.levels.WARN)
    return
  end

  vim.ui.select(groups, { prompt = "Move to group:" }, function(to_group)
    if to_group then
      local ok, err = state_module.move_item(from_group, row, to_group)
      if ok then
        vim.notify("Moved to " .. to_group, vim.log.levels.INFO)
        mp_state:render_panel("items")
      else
        vim.notify(err or "Failed to move item", vim.log.levels.ERROR)
      end
    end
  end)
end

---Handle Sort key
---@param mp_state MultiPanelState
local function handle_sort(mp_state)
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

    vim.notify("Items sorted: " .. next_mode, vim.log.levels.INFO)
    mp_state:render_panel("items")
  end
end

---Handle move up (reorder)
---@param mp_state MultiPanelState
local function handle_move_up(mp_state)
  local focused = mp_state.focused_panel
  local ui_state = state_module.load_ui_state()

  if focused == "groups" then
    if ui_state.left_sort_mode ~= "custom" then
      vim.notify("Reorder only works in custom sort mode", vim.log.levels.INFO)
      return
    end

    local row = mp_state:get_cursor("groups")
    local nodes = mp_state.data and mp_state.data.tree_nodes or {}
    local node = get_node_at_line(nodes, row)
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
      state_module.reorder_up("group", parent_path, idx)
      mp_state:render_panel("groups")
      mp_state:set_cursor("groups", row - 1)
    end
  else
    if ui_state.right_sort_mode ~= "custom" then
      vim.notify("Reorder only works in custom sort mode", vim.log.levels.INFO)
      return
    end

    local group_path = ui_state.last_selected_group
    if not group_path then return end

    local row = mp_state:get_cursor("items")
    if row > 1 then
      state_module.reorder_up("item", group_path, row)
      mp_state:render_panel("items")
      mp_state:set_cursor("items", row - 1)
    end
  end
end

---Handle move down (reorder)
---@param mp_state MultiPanelState
local function handle_move_down(mp_state)
  local focused = mp_state.focused_panel
  local ui_state = state_module.load_ui_state()

  if focused == "groups" then
    if ui_state.left_sort_mode ~= "custom" then
      vim.notify("Reorder only works in custom sort mode", vim.log.levels.INFO)
      return
    end

    local row = mp_state:get_cursor("groups")
    local nodes = mp_state.data and mp_state.data.tree_nodes or {}
    local node = get_node_at_line(nodes, row)
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
      state_module.reorder_down("group", parent_path, idx)
      mp_state:render_panel("groups")
      mp_state:set_cursor("groups", row + 1)
    end
  else
    if ui_state.right_sort_mode ~= "custom" then
      vim.notify("Reorder only works in custom sort mode", vim.log.levels.INFO)
      return
    end

    local group_path = ui_state.last_selected_group
    if not group_path then return end

    local row = mp_state:get_cursor("items")
    local items = mp_state.data and mp_state.data.current_items or {}

    if row < #items then
      state_module.reorder_down("item", group_path, row)
      mp_state:render_panel("items")
      mp_state:set_cursor("items", row + 1)
    end
  end
end

---Handle open in split
---@param mp_state MultiPanelState
---@param split_cmd string "split" or "vsplit" or "tabnew"
local function handle_open_split(mp_state, split_cmd)
  if mp_state.focused_panel ~= "items" then
    vim.notify("Select an item in the right panel", vim.log.levels.INFO)
    return
  end

  local row = mp_state:get_cursor("items")
  local items = mp_state.data and mp_state.data.current_items or {}

  if row < 1 or row > #items then return end

  local item = items[row]
  mp_state:close()

  vim.cmd(split_cmd)
  if item.type == "dir" then
    vim.cmd.cd(item.path)
  else
    vim.cmd.edit(item.path)
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Show the favorites UI
---@param config FavdirConfig
function M.show(config)
  if panel_state and panel_state:is_valid() then
    -- Already open, focus it
    panel_state:focus_panel(panel_state.focused_panel)
    return
  end

  local nf = require("nvim-float")

  local total_height = math.floor(vim.o.lines * config.window_height_ratio)
  local total_width = math.floor(vim.o.columns * config.window_width_ratio)

  panel_state = nf.create_multi_panel({
    layout = {
      split = "horizontal",
      children = {
        {
          name = "groups",
          title = " Groups ",
          ratio = config.left_panel_width_ratio,
          on_render = render_left_panel,
        },
        {
          name = "items",
          title = " Items ",
          ratio = 1 - config.left_panel_width_ratio,
          on_render = render_right_panel,
        },
      },
    },
    total_width_ratio = config.window_width_ratio,
    total_height_ratio = config.window_height_ratio,
    footer = "? = Help",
    initial_focus = "groups",
    controls = {
      { key = "<CR>", desc = "Select/Toggle" },
      { key = "<Tab>", desc = "Switch panel" },
      { key = "a", desc = "Add group/item" },
      { key = "d", desc = "Delete" },
      { key = "r", desc = "Rename group" },
      { key = "m", desc = "Move item" },
      { key = "s", desc = "Cycle sort" },
      { key = "<C-k>/<C-j>", desc = "Reorder" },
      { key = "<C-s>", desc = "Open in split" },
      { key = "<C-v>", desc = "Open in vsplit" },
      { key = "<C-t>", desc = "Open in tab" },
      { key = "q/<Esc>", desc = "Close" },
    },
    on_close = function()
      panel_state = nil
    end,
  })

  if not panel_state then
    vim.notify("Failed to create favorites UI", vim.log.levels.ERROR)
    return
  end

  -- Render initial content
  panel_state:render_all()

  -- Restore cursor positions
  local ui_state = state_module.load_ui_state()
  if ui_state.left_cursor then
    panel_state:set_cursor("groups", ui_state.left_cursor.row, ui_state.left_cursor.col)
  end
  if ui_state.right_cursor then
    panel_state:set_cursor("items", ui_state.right_cursor.row, ui_state.right_cursor.col)
  end

  -- Setup keymaps
  panel_state:set_keymaps({
    ["<CR>"] = function() handle_enter(panel_state) end,
    ["<Tab>"] = function() panel_state:focus_next_panel() end,
    ["<S-Tab>"] = function() panel_state:focus_prev_panel() end,
    ["a"] = function() handle_add(panel_state) end,
    ["d"] = function() handle_delete(panel_state) end,
    ["r"] = function() handle_rename(panel_state) end,
    ["m"] = function() handle_move(panel_state) end,
    ["s"] = function() handle_sort(panel_state) end,
    ["<C-k>"] = function() handle_move_up(panel_state) end,
    ["<C-j>"] = function() handle_move_down(panel_state) end,
    ["<C-s>"] = function() handle_open_split(panel_state, "split") end,
    ["<C-v>"] = function() handle_open_split(panel_state, "vsplit") end,
    ["<C-t>"] = function() handle_open_split(panel_state, "tabnew") end,
    ["q"] = function()
      -- Save cursor positions before closing
      local row_l, col_l = panel_state:get_cursor("groups")
      local row_r, col_r = panel_state:get_cursor("items")
      local uis = state_module.load_ui_state()
      uis.left_cursor = { row = row_l, col = col_l }
      uis.right_cursor = { row = row_r, col = col_r }
      state_module.save_ui_state(uis)
      panel_state:close()
    end,
    ["<Esc>"] = function()
      local row_l, col_l = panel_state:get_cursor("groups")
      local row_r, col_r = panel_state:get_cursor("items")
      local uis = state_module.load_ui_state()
      uis.left_cursor = { row = row_l, col = col_l }
      uis.right_cursor = { row = row_r, col = col_r }
      state_module.save_ui_state(uis)
      panel_state:close()
    end,
  })
end

---Toggle the UI
---@param config FavdirConfig
function M.toggle(config)
  if panel_state and panel_state:is_valid() then
    panel_state:close()
  else
    M.show(config)
  end
end

---Pick a group and add an item to it
---@param config FavdirConfig
---@param item_path string Path to add
function M.pick_group_and_add_item(config, item_path)
  local groups = state_module.get_group_list()

  if #groups == 0 then
    vim.notify("No groups available. Create one first.", vim.log.levels.WARN)
    return
  end

  vim.ui.select(groups, { prompt = "Add to group:" }, function(group)
    if group then
      local ok, err = state_module.add_item(group, item_path)
      if not ok then
        vim.notify(err or "Failed to add item", vim.log.levels.ERROR)
      end
    end
  end)
end

return M
