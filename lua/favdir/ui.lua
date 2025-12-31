---@class FavdirUI
---Multi-panel UI for managing favorite directories
---@module favdir.ui

local M = {}

local state_module = require("favdir.state")

---@type MultiPanelState?
local panel_state = nil

-- ============================================================================
-- Icons - Unified icon definitions with Nerd Font, ASCII, and colors
-- ============================================================================

-- Helper to convert codepoint to UTF-8 character
local function nf(codepoint)
  return vim.fn.nr2char(codepoint)
end

-- Whether to use Nerd Font icons (set by select_icon_set)
local use_nerd_font = true

---@class IconDef
---@field nerd string Nerd Font icon
---@field ascii string ASCII fallback
---@field color string? Hex color for the icon

---@class BaseIconDef
---@field nerd string Nerd Font icon
---@field ascii string ASCII fallback

-- Base UI icons (expand/collapse, directory, file)
---@type table<string, BaseIconDef>
local base_icons = {
  expanded   = { nerd = "▼",           ascii = "[-]" },
  collapsed  = { nerd = "▶",           ascii = "[+]" },
  leaf       = { nerd = "•",           ascii = " - " },  -- Bullet for leaf nodes
  directory  = { nerd = nf(0xF07B),    ascii = "[D]" },  -- nf-fa-folder
  file       = { nerd = nf(0xF15B),    ascii = "[F]" },  -- nf-fa-file
}

-- File extension icons with colors (from nvim-web-devicons)
---@type table<string, IconDef>
local file_icons = {
  -- Lua
  lua      = { nerd = nf(0xE620), ascii = "lua", color = "#51A0CF" },

  -- Python
  py       = { nerd = nf(0xE73C), ascii = "py",  color = "#FFDC51" },
  python   = { nerd = nf(0xE73C), ascii = "py",  color = "#FFDC51" },
  pyw      = { nerd = nf(0xE73C), ascii = "py",  color = "#FFDC51" },
  pyx      = { nerd = nf(0xE73C), ascii = "py",  color = "#FFDC51" },

  -- JavaScript/TypeScript
  js       = { nerd = nf(0xE74E), ascii = "js",  color = "#F1E05A" },
  mjs      = { nerd = nf(0xE74E), ascii = "js",  color = "#F1E05A" },
  cjs      = { nerd = nf(0xE74E), ascii = "js",  color = "#F1E05A" },
  ts       = { nerd = nf(0xE628), ascii = "ts",  color = "#3178C6" },
  mts      = { nerd = nf(0xE628), ascii = "ts",  color = "#3178C6" },
  tsx      = { nerd = nf(0xE7BA), ascii = "tsx", color = "#20C2E3" },
  jsx      = { nerd = nf(0xE7BA), ascii = "jsx", color = "#20C2E3" },

  -- Web
  json     = { nerd = nf(0xE60B), ascii = "{}", color = "#CBCB41" },
  jsonc    = { nerd = nf(0xE60B), ascii = "{}", color = "#CBCB41" },
  html     = { nerd = nf(0xE736), ascii = "<>", color = "#E44D26" },
  htm      = { nerd = nf(0xE736), ascii = "<>", color = "#E44D26" },
  css      = { nerd = nf(0xE749), ascii = "#",  color = "#563D7C" },
  scss     = { nerd = nf(0xE749), ascii = "#",  color = "#CF649A" },
  sass     = { nerd = nf(0xE749), ascii = "#",  color = "#CF649A" },
  less     = { nerd = nf(0xE749), ascii = "#",  color = "#1D365D" },
  vue      = { nerd = nf(0xE6A0), ascii = "vue", color = "#42B883" },
  svelte   = { nerd = nf(0xE697), ascii = "sve", color = "#FF3E00" },

  -- Markdown/Docs
  md       = { nerd = nf(0xE609), ascii = "md",  color = "#DDDDDD" },
  markdown = { nerd = nf(0xE609), ascii = "md",  color = "#DDDDDD" },
  mdx      = { nerd = nf(0xE609), ascii = "mdx", color = "#DDDDDD" },
  txt      = { nerd = nf(0xF15C), ascii = "txt", color = "#89E051" },
  rst      = { nerd = nf(0xF15C), ascii = "rst", color = "#89E051" },

  -- Config/Data
  yaml     = { nerd = nf(0xE6A8), ascii = "yml", color = "#CB171E" },
  yml      = { nerd = nf(0xE6A8), ascii = "yml", color = "#CB171E" },
  toml     = { nerd = nf(0xE615), ascii = "cfg", color = "#9C4121" },
  xml      = { nerd = nf(0xE619), ascii = "xml", color = "#E37933" },
  ini      = { nerd = nf(0xE615), ascii = "ini", color = "#6D8086" },
  conf     = { nerd = nf(0xE615), ascii = "cfg", color = "#6D8086" },
  config   = { nerd = nf(0xE615), ascii = "cfg", color = "#6D8086" },
  env      = { nerd = nf(0xF462), ascii = "env", color = "#ECD53F" },

  -- Shell
  sh       = { nerd = nf(0xF489), ascii = "$",   color = "#4EAA25" },
  bash     = { nerd = nf(0xF489), ascii = "$",   color = "#4EAA25" },
  zsh      = { nerd = nf(0xF489), ascii = "$",   color = "#4EAA25" },
  fish     = { nerd = nf(0xF489), ascii = "$",   color = "#4EAA25" },
  ps1      = { nerd = nf(0xF489), ascii = ">_",  color = "#012456" },
  bat      = { nerd = nf(0xF489), ascii = ">_",  color = "#C1F12E" },
  cmd      = { nerd = nf(0xF489), ascii = ">_",  color = "#C1F12E" },

  -- C/C++
  c        = { nerd = nf(0xE61E), ascii = "C",   color = "#599EFF" },
  h        = { nerd = nf(0xE61E), ascii = "H",   color = "#A074C4" },
  cpp      = { nerd = nf(0xE61D), ascii = "C+",  color = "#F34B7D" },
  cc       = { nerd = nf(0xE61D), ascii = "C+",  color = "#F34B7D" },
  cxx      = { nerd = nf(0xE61D), ascii = "C+",  color = "#F34B7D" },
  hpp      = { nerd = nf(0xE61D), ascii = "H+",  color = "#A074C4" },
  hxx      = { nerd = nf(0xE61D), ascii = "H+",  color = "#A074C4" },

  -- Rust/Go
  rs       = { nerd = nf(0xE7A8), ascii = "rs",  color = "#DEA584" },
  go       = { nerd = nf(0xE626), ascii = "go",  color = "#00ADD8" },
  mod      = { nerd = nf(0xE626), ascii = "mod", color = "#00ADD8" },
  sum      = { nerd = nf(0xE626), ascii = "sum", color = "#00ADD8" },

  -- JVM
  java     = { nerd = nf(0xE738), ascii = "jav", color = "#CC3E44" },
  jar      = { nerd = nf(0xE738), ascii = "jar", color = "#CC3E44" },
  kt       = { nerd = nf(0xE634), ascii = "kt",  color = "#7F52FF" },
  kts      = { nerd = nf(0xE634), ascii = "kts", color = "#7F52FF" },
  scala    = { nerd = nf(0xE737), ascii = "sca", color = "#CC3E44" },
  groovy   = { nerd = nf(0xE775), ascii = "gvy", color = "#4298B8" },
  gradle   = { nerd = nf(0xE660), ascii = "grd", color = "#02303A" },

  -- Ruby/PHP
  rb       = { nerd = nf(0xE739), ascii = "rb",  color = "#CC342D" },
  ruby     = { nerd = nf(0xE739), ascii = "rb",  color = "#CC342D" },
  erb      = { nerd = nf(0xE739), ascii = "erb", color = "#CC342D" },
  php      = { nerd = nf(0xE73D), ascii = "php", color = "#777BB3" },

  -- .NET
  cs       = { nerd = nf(0xF81A), ascii = "C#",  color = "#68217A" },
  fs       = { nerd = nf(0xE7A7), ascii = "F#",  color = "#378BBA" },
  vb       = { nerd = nf(0xF81A), ascii = "vb",  color = "#945DB7" },
  sln      = { nerd = nf(0xE70C), ascii = "sln", color = "#854CC7" },

  -- Database
  sql      = { nerd = nf(0xE706), ascii = "sql", color = "#67c1f5" },
  db       = { nerd = nf(0xE706), ascii = "db",  color = "#e0ffb6" },
  sqlite   = { nerd = nf(0xE706), ascii = "sql", color = "#0F80CC" },

  -- Vim/Editor
  vim      = { nerd = nf(0xE62B), ascii = "vim", color = "#019833" },
  nvim     = { nerd = nf(0xE62B), ascii = "vim", color = "#019833" },

  -- Git
  git           = { nerd = nf(0xE702), ascii = "git", color = "#F14C28" },
  gitignore     = { nerd = nf(0xE702), ascii = "git", color = "#F14C28" },
  gitattributes = { nerd = nf(0xE702), ascii = "git", color = "#F14C28" },
  gitmodules    = { nerd = nf(0xE702), ascii = "git", color = "#F14C28" },

  -- Docker
  dockerfile    = { nerd = nf(0xE7B0), ascii = "doc", color = "#2496ED" },
  docker        = { nerd = nf(0xE7B0), ascii = "doc", color = "#2496ED" },
  dockerignore  = { nerd = nf(0xE7B0), ascii = "doc", color = "#2496ED" },

  -- Build/Config files
  makefile = { nerd = nf(0xE779), ascii = "mk",  color = "#6D8086" },
  cmake    = { nerd = nf(0xE615), ascii = "cmk", color = "#6D8086" },
  rake     = { nerd = nf(0xE739), ascii = "rak", color = "#CC342D" },
  just     = { nerd = nf(0xE615), ascii = "jst", color = "#6D8086" },

  -- Images
  png      = { nerd = nf(0xF1C5), ascii = "img", color = "#A074C4" },
  jpg      = { nerd = nf(0xF1C5), ascii = "img", color = "#A074C4" },
  jpeg     = { nerd = nf(0xF1C5), ascii = "img", color = "#A074C4" },
  gif      = { nerd = nf(0xF1C5), ascii = "gif", color = "#A074C4" },
  svg      = { nerd = nf(0xF1C5), ascii = "svg", color = "#FFB13B" },
  ico      = { nerd = nf(0xF1C5), ascii = "ico", color = "#CBCB41" },
  webp     = { nerd = nf(0xF1C5), ascii = "img", color = "#A074C4" },
  bmp      = { nerd = nf(0xF1C5), ascii = "bmp", color = "#A074C4" },

  -- Archives
  zip      = { nerd = nf(0xF1C6), ascii = "zip", color = "#ECA517" },
  tar      = { nerd = nf(0xF1C6), ascii = "tar", color = "#ECA517" },
  gz       = { nerd = nf(0xF1C6), ascii = "gz",  color = "#ECA517" },
  rar      = { nerd = nf(0xF1C6), ascii = "rar", color = "#ECA517" },
  ["7z"]   = { nerd = nf(0xF1C6), ascii = "7z",  color = "#ECA517" },

  -- Lock files
  lock     = { nerd = nf(0xF023), ascii = "lck", color = "#BBBBBB" },

  -- Misc
  log      = { nerd = nf(0xF18D), ascii = "log", color = "#DDDDDD" },
  pdf      = { nerd = nf(0xF1C1), ascii = "pdf", color = "#B30B00" },
  license  = { nerd = nf(0xF0219), ascii = "lic", color = "#CBCB41" },
}

-- Default colors for base icons
local base_colors = {
  directory = "#E8AB53",  -- Folder yellow
  file = "#6D8086",       -- Default file gray
}

---Get a base icon (expanded, collapsed, directory, file)
---@param icon_name string
---@return string icon
local function get_base_icon(icon_name)
  local def = base_icons[icon_name]
  if not def then
    return "?"
  end
  return use_nerd_font and def.nerd or def.ascii
end

---Get icon and color for a file extension
---@param path string
---@return string icon, string? color
local function get_file_icon(path)
  local name = vim.fn.fnamemodify(path, ':t'):lower()
  local ext = vim.fn.fnamemodify(path, ':e'):lower()

  -- Check full filename first (for dotfiles like .gitignore)
  local def = file_icons[name]
  if def then
    local icon = use_nerd_font and def.nerd or def.ascii
    return icon, def.color
  end

  -- Check extension
  def = file_icons[ext]
  if def then
    local icon = use_nerd_font and def.nerd or def.ascii
    return icon, def.color
  end

  -- Default file icon
  local base = base_icons.file
  return use_nerd_font and base.nerd or base.ascii, base_colors.file
end

---Select icon set based on config
---@param use_nerd boolean
local function select_icon_set(use_nerd)
  use_nerd_font = use_nerd
end

-- Cache for dynamically created highlight groups
local hl_cache = {}

---Get or create a highlight group for an icon color
---@param color string Hex color like "#51A0CF"
---@return string hl_group_name
local function get_icon_hl(color)
  if not color then
    return nil
  end

  -- Create a safe highlight group name from the color
  local hl_name = "FavdirIcon_" .. color:gsub("#", "")

  -- Cache and create the highlight group if it doesn't exist
  if not hl_cache[hl_name] then
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
    hl_cache[hl_name] = true
  end

  return hl_name
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
      icon = node.is_expanded and get_base_icon("expanded") or get_base_icon("collapsed")
    else
      icon = get_base_icon("leaf")
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
    local icon, color
    if item.type == "dir" then
      icon = get_base_icon("directory")
      color = base_colors.directory
    else
      icon, color = get_file_icon(item.path)
    end

    local name = vim.fn.fnamemodify(item.path, ':t')

    -- Shorten home directory
    local display_path = item.path
    local home = vim.fn.expand('~')
    if vim.startswith(display_path, home) then
      display_path = "~" .. display_path:sub(#home + 1)
    end

    local icon_hl = get_icon_hl(color)

    if item.type == "dir" then
      cb:spans({
        { text = icon .. " ", hl_group = icon_hl },
        { text = name, style = "strong" },
        { text = " ", style = "muted" },
        { text = display_path, style = "muted" },
      })
    else
      cb:spans({
        { text = icon .. " ", hl_group = icon_hl },
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
    local title = parent_path ~= "" and ("Add Child to " .. parent_path) or "Add New Group"

    show_input_popup(title, "Group Name:", "", function(name)
        local ok, err = state_module.add_group(parent_path, name)
        if ok then
          -- Expand parent to show new child
          if parent_path ~= "" then
            local ui_state = state_module.load_ui_state()
            if not state_module.is_expanded(ui_state, parent_path) then
              state_module.toggle_expanded(parent_path)
            end
          end
          -- Schedule render to ensure it happens after callback completes
          vim.schedule(function()
            if mp_state and mp_state:is_valid() then
          mp_state:render_panel("groups")
            end
          end)
        else
          vim.notify(err or "Failed to add group", vim.log.levels.ERROR)
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

    -- Use nvim-float select popup
    show_select_popup("Add to " .. group_path, { "Current directory", "Current file", "Enter path..." }, function(idx, choice)
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
        -- Show input popup for custom path
        show_input_popup("Add Path", "Path:", "", function(input)
              local ok, err = state_module.add_item(group_path, input)
              if ok then
            vim.schedule(function()
              if mp_state and mp_state:is_valid() then
                mp_state:render_panel("items")
              end
            end)
              else
                vim.notify(err or "Failed to add item", vim.log.levels.ERROR)
            end
          end)
          return
        end

        local ok, err = state_module.add_item(group_path, path)
        if ok then
        vim.schedule(function()
          if mp_state and mp_state:is_valid() then
          mp_state:render_panel("items")
          end
        end)
        else
          vim.notify(err or "Failed to add item", vim.log.levels.ERROR)
        end
    end)
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
          vim.schedule(function()
            if mp_state and mp_state:is_valid() then
          mp_state:render_panel("groups")
          mp_state:render_panel("items")
            end
          end)
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
          vim.schedule(function()
            if mp_state and mp_state:is_valid() then
          mp_state:render_panel("items")
            end
          end)
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
          vim.schedule(function()
            if mp_state and mp_state:is_valid() then
          mp_state:render_panel("groups")
            end
          end)
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
        vim.schedule(function()
          if mp_state and mp_state:is_valid() then
        mp_state:render_panel("items")
          end
        end)
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
  -- Select icon set based on config (Nerd Font or ASCII)
  select_icon_set(config.use_nerd_font == true)

  if panel_state and panel_state:is_valid() then
    -- Already open, focus it
    panel_state:focus_panel(panel_state.focused_panel)
    return
  end

  local nvim_float = require("nvim-float")

  local total_height = math.floor(vim.o.lines * config.window_height_ratio)
  local total_width = math.floor(vim.o.columns * config.window_width_ratio)

  panel_state = nvim_float.create_multi_panel({
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
    footer = "? = Controls",
    initial_focus = "groups",
    controls = {
      {
        header = "Navigation",
        keys = {
      { key = "<CR>", desc = "Select/Toggle" },
          { key = "<Tab>/<S-Tab>", desc = "Switch panel" },
          { key = "j/k", desc = "Move cursor" },
        },
      },
      {
        header = "Actions",
        keys = {
      { key = "a", desc = "Add group/item" },
      { key = "d", desc = "Delete" },
      { key = "r", desc = "Rename group" },
          { key = "m", desc = "Move item to group" },
        },
      },
      {
        header = "Sorting",
        keys = {
          { key = "s", desc = "Cycle sort mode" },
          { key = "<C-k>/<C-j>", desc = "Reorder up/down" },
        },
      },
      {
        header = "Open Options",
        keys = {
      { key = "<C-s>", desc = "Open in split" },
      { key = "<C-v>", desc = "Open in vsplit" },
      { key = "<C-t>", desc = "Open in tab" },
        },
      },
      {
        header = "Window",
        keys = {
      { key = "q/<Esc>", desc = "Close" },
        },
      },
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
