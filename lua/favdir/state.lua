---@class FavdirState
---Data persistence and state management for favdir
---@module favdir.state

local M = {}

---@type FavdirConfig?
local config = nil

-- ============================================================================
-- Data Structures
-- ============================================================================

---@class FavdirItem
---@field path string Absolute path to file or directory
---@field type "dir"|"file" Item type
---@field order number Sort order within group

---@class FavdirGroup
---@field name string Group name
---@field items FavdirItem[] Files and directories in this group
---@field order number Sort order
---@field children FavdirGroup[]? Child groups (for hierarchy)

---@class FavdirData
---@field groups FavdirGroup[] Top-level groups

---@class FavdirUIState
---@field expanded_groups string[] List of expanded group paths (e.g., "Work.Projects")
---@field last_selected_group string? Last selected group path
---@field focused_panel "left"|"right" Currently focused panel
---@field left_cursor {row: number, col: number} Left panel cursor position
---@field right_cursor {row: number, col: number} Right panel cursor position
---@field left_sort_mode "custom"|"alpha" Left panel sort mode
---@field right_sort_mode "custom"|"alpha"|"type" Right panel sort mode

-- ============================================================================
-- Initialization
-- ============================================================================

---Initialize the state module with config
---@param cfg FavdirConfig
function M.init(cfg)
  config = cfg
end

-- ============================================================================
-- Data Persistence - Main Data
-- ============================================================================

---Create default data structure
---@return FavdirData
local function create_default_data()
  local groups = {}
  -- Only create groups if configured
  if config and config.default_groups then
    for i, name in ipairs(config.default_groups) do
      table.insert(groups, {
        name = name,
        items = {},
        order = i,
        children = {},
      })
    end
  end
  return { groups = groups }
end

---Load data from file
---@return FavdirData
function M.load_data()
  if not config then
    return create_default_data()
  end

  local path = config.data_file
  if vim.fn.filereadable(path) == 0 then
    return create_default_data()
  end

  local content = vim.fn.readfile(path)
  if #content == 0 then
    return create_default_data()
  end

  local ok, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  if not ok or type(data) ~= "table" or not data.groups then
    vim.notify("favdir: Failed to parse data file, using defaults", vim.log.levels.WARN)
    return create_default_data()
  end

  return data
end

---Save data to file
---@param data FavdirData
---@return boolean success
function M.save_data(data)
  if not config then
    return false
  end

  local path = config.data_file
  local dir = vim.fn.fnamemodify(path, ':h')

  -- Ensure directory exists
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end

  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    vim.notify("favdir: Failed to encode data", vim.log.levels.ERROR)
    return false
  end

  local write_ok = pcall(vim.fn.writefile, { json }, path)
  if not write_ok then
    vim.notify("favdir: Failed to write data file", vim.log.levels.ERROR)
    return false
  end

  return true
end

-- ============================================================================
-- Data Persistence - UI State
-- ============================================================================

---Create default UI state
---@return FavdirUIState
local function create_default_ui_state()
  return {
    expanded_groups = {},
    last_selected_group = nil,
    focused_panel = "left",
    left_cursor = { row = 1, col = 0 },
    right_cursor = { row = 1, col = 0 },
    left_sort_mode = "custom",
    right_sort_mode = "custom",
  }
end

---Load UI state from file
---@return FavdirUIState
function M.load_ui_state()
  if not config then
    return create_default_ui_state()
  end

  local path = config.ui_state_file
  if vim.fn.filereadable(path) == 0 then
    return create_default_ui_state()
  end

  local content = vim.fn.readfile(path)
  if #content == 0 then
    return create_default_ui_state()
  end

  local ok, state = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  if not ok or type(state) ~= "table" then
    return create_default_ui_state()
  end

  -- Merge with defaults to handle missing fields
  return vim.tbl_deep_extend("force", create_default_ui_state(), state)
end

---Save UI state to file
---@param state FavdirUIState
---@return boolean success
function M.save_ui_state(state)
  if not config then
    return false
  end

  local path = config.ui_state_file
  local dir = vim.fn.fnamemodify(path, ':h')

  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end

  local ok, json = pcall(vim.fn.json_encode, state)
  if not ok then
    return false
  end

  local write_ok = pcall(vim.fn.writefile, { json }, path)
  return write_ok == true
end

-- ============================================================================
-- Group Management
-- ============================================================================

---Find a group by path (e.g., "Work.Projects.Active")
---@param data FavdirData
---@param group_path string Dot-separated path
---@return FavdirGroup?, FavdirGroup[]? parent_list The group and its parent list
function M.find_group(data, group_path)
  if not group_path or group_path == "" then
    return nil, nil
  end

  local parts = vim.split(group_path, ".", { plain = true })
  local current_list = data.groups
  local group = nil

  for _, part in ipairs(parts) do
    group = nil
    for _, g in ipairs(current_list) do
      if g.name == part then
        group = g
        break
      end
    end
    if not group then
      return nil, nil
    end
    current_list = group.children or {}
  end

  -- Find parent list for removal/reordering
  if #parts == 1 then
    return group, data.groups
  else
    local parent_path = table.concat(vim.list_slice(parts, 1, #parts - 1), ".")
    local parent = M.find_group(data, parent_path)
    if parent then
      return group, parent.children
    end
  end

  return group, nil
end

---Get next order number for a list
---@param list FavdirGroup[]|FavdirItem[]
---@return number
local function get_next_order(list)
  local max_order = 0
  for _, item in ipairs(list) do
    if item.order and item.order > max_order then
      max_order = item.order
    end
  end
  return max_order + 1
end

---Add a new group
---@param parent_path string? Parent group path (nil for root)
---@param name string Group name
---@return boolean success
---@return string? error_message
function M.add_group(parent_path, name)
  if not name or name == "" then
    return false, "Group name cannot be empty"
  end

  local data = M.load_data()
  local target_list

  if not parent_path or parent_path == "" then
    target_list = data.groups
  else
    local parent = M.find_group(data, parent_path)
    if not parent then
      return false, "Parent group not found"
    end
    parent.children = parent.children or {}
    target_list = parent.children
  end

  -- Check for duplicate
  for _, g in ipairs(target_list) do
    if g.name == name then
      return false, "Group already exists"
    end
  end

  -- Add new group
  table.insert(target_list, {
    name = name,
    items = {},
    order = get_next_order(target_list),
    children = {},
  })

  M.save_data(data)
  return true, nil
end

---Remove a group
---@param group_path string Group path to remove
---@return boolean success
---@return string? error_message
function M.remove_group(group_path)
  local data = M.load_data()
  local group, parent_list = M.find_group(data, group_path)

  if not group or not parent_list then
    return false, "Group not found"
  end

  -- Check if protected
  if config and vim.tbl_contains(config.protected_groups, group.name) then
    return false, "Cannot delete protected group"
  end

  -- Remove from parent list
  for i, g in ipairs(parent_list) do
    if g.name == group.name then
      table.remove(parent_list, i)
      break
    end
  end

  -- Update UI state to remove from expanded groups
  local ui_state = M.load_ui_state()
  ui_state.expanded_groups = vim.tbl_filter(function(path)
    return not vim.startswith(path, group_path)
  end, ui_state.expanded_groups)
  M.save_ui_state(ui_state)

  M.save_data(data)
  return true, nil
end

---Rename a group
---@param group_path string Current group path
---@param new_name string New name
---@return boolean success
---@return string? error_message
function M.rename_group(group_path, new_name)
  if not new_name or new_name == "" then
    return false, "Name cannot be empty"
  end

  local data = M.load_data()
  local group, parent_list = M.find_group(data, group_path)

  if not group or not parent_list then
    return false, "Group not found"
  end

  -- Check for duplicate at same level
  for _, g in ipairs(parent_list) do
    if g.name == new_name and g ~= group then
      return false, "A group with this name already exists"
    end
  end

  local old_name = group.name
  group.name = new_name

  -- Update UI state expanded_groups paths
  local ui_state = M.load_ui_state()
  local new_expanded = {}
  for _, path in ipairs(ui_state.expanded_groups) do
    if path == group_path then
      -- Replace this exact path
      local parts = vim.split(group_path, ".", { plain = true })
      parts[#parts] = new_name
      table.insert(new_expanded, table.concat(parts, "."))
    elseif vim.startswith(path, group_path .. ".") then
      -- Replace prefix for child paths
      local suffix = path:sub(#group_path + 2)
      local parts = vim.split(group_path, ".", { plain = true })
      parts[#parts] = new_name
      table.insert(new_expanded, table.concat(parts, ".") .. "." .. suffix)
    else
      table.insert(new_expanded, path)
    end
  end
  ui_state.expanded_groups = new_expanded
  M.save_ui_state(ui_state)

  M.save_data(data)
  return true, nil
end

---Get flat list of all group paths
---@return string[]
function M.get_group_list()
  local data = M.load_data()
  local result = {}

  local function collect(groups, prefix)
    for _, g in ipairs(groups) do
      local path = prefix == "" and g.name or (prefix .. "." .. g.name)
      table.insert(result, path)
      if g.children and #g.children > 0 then
        collect(g.children, path)
      end
    end
  end

  collect(data.groups, "")
  return result
end

-- ============================================================================
-- Item Management
-- ============================================================================

---Add an item (file or directory) to a group
---@param group_path string Group path
---@param item_path string Path to file or directory
---@return boolean success
---@return string? error_message
function M.add_item(group_path, item_path)
  -- Normalize path
  local abs_path = vim.fn.fnamemodify(item_path, ':p')

  -- Determine type
  local item_type = "file"
  if vim.fn.isdirectory(abs_path) == 1 then
    item_type = "dir"
  elseif vim.fn.filereadable(abs_path) == 0 then
    return false, "Path does not exist: " .. abs_path
  end

  local data = M.load_data()
  local group = M.find_group(data, group_path)

  if not group then
    return false, "Group not found"
  end

  -- Check for duplicate
  for _, item in ipairs(group.items) do
    if item.path == abs_path then
      return false, "Item already exists in this group"
    end
  end

  -- Add item
  table.insert(group.items, {
    path = abs_path,
    type = item_type,
    order = get_next_order(group.items),
  })

  M.save_data(data)
  vim.notify(string.format("Added %s to %s", vim.fn.fnamemodify(abs_path, ':t'), group_path), vim.log.levels.INFO)
  return true, nil
end

---Remove an item from a group
---@param group_path string Group path
---@param item_index number 1-based index
---@return boolean success
---@return string? error_message
function M.remove_item(group_path, item_index)
  local data = M.load_data()
  local group = M.find_group(data, group_path)

  if not group then
    return false, "Group not found"
  end

  if item_index < 1 or item_index > #group.items then
    return false, "Invalid item index"
  end

  table.remove(group.items, item_index)

  -- Renumber order
  for i, item in ipairs(group.items) do
    item.order = i
  end

  M.save_data(data)
  return true, nil
end

---Move an item to another group
---@param from_group string Source group path
---@param item_index number 1-based index of item
---@param to_group string Target group path
---@return boolean success
---@return string? error_message
function M.move_item(from_group, item_index, to_group)
  local data = M.load_data()
  local source = M.find_group(data, from_group)
  local target = M.find_group(data, to_group)

  if not source then
    return false, "Source group not found"
  end
  if not target then
    return false, "Target group not found"
  end
  if item_index < 1 or item_index > #source.items then
    return false, "Invalid item index"
  end

  local item = table.remove(source.items, item_index)

  -- Check for duplicate in target
  for _, existing in ipairs(target.items) do
    if existing.path == item.path then
      -- Put it back
      table.insert(source.items, item_index, item)
      return false, "Item already exists in target group"
    end
  end

  item.order = get_next_order(target.items)
  table.insert(target.items, item)

  -- Renumber source
  for i, it in ipairs(source.items) do
    it.order = i
  end

  M.save_data(data)
  return true, nil
end

-- ============================================================================
-- Sorting and Ordering
-- ============================================================================

---Sort groups at a given level
---@param parent_path string? Parent path (nil for root)
---@param mode "custom"|"alpha"
function M.sort_groups(parent_path, mode)
  local data = M.load_data()
  local groups

  if not parent_path or parent_path == "" then
    groups = data.groups
  else
    local parent = M.find_group(data, parent_path)
    if parent then
      groups = parent.children or {}
    else
      return
    end
  end

  if mode == "alpha" then
    table.sort(groups, function(a, b)
      return a.name:lower() < b.name:lower()
    end)
    -- Update order numbers
    for i, g in ipairs(groups) do
      g.order = i
    end
  else
    -- Custom: sort by order field
    table.sort(groups, function(a, b)
      return (a.order or 0) < (b.order or 0)
    end)
  end

  M.save_data(data)
end

---Sort items in a group
---@param group_path string Group path
---@param mode "custom"|"alpha"|"type"
function M.sort_items(group_path, mode)
  local data = M.load_data()
  local group = M.find_group(data, group_path)

  if not group then
    return
  end

  if mode == "alpha" then
    table.sort(group.items, function(a, b)
      local name_a = vim.fn.fnamemodify(a.path, ':t'):lower()
      local name_b = vim.fn.fnamemodify(b.path, ':t'):lower()
      return name_a < name_b
    end)
  elseif mode == "type" then
    table.sort(group.items, function(a, b)
      -- Directories first, then files
      if a.type ~= b.type then
        return a.type == "dir"
      end
      local name_a = vim.fn.fnamemodify(a.path, ':t'):lower()
      local name_b = vim.fn.fnamemodify(b.path, ':t'):lower()
      return name_a < name_b
    end)
  else
    -- Custom: sort by order
    table.sort(group.items, function(a, b)
      return (a.order or 0) < (b.order or 0)
    end)
  end

  -- Update order numbers
  for i, item in ipairs(group.items) do
    item.order = i
  end

  M.save_data(data)
end

---Reorder an item up
---@param item_type "group"|"item"
---@param path string Group path (for items) or group's parent path (for groups)
---@param index number Current 1-based index
---@return number new_index New position
function M.reorder_up(item_type, path, index)
  if index <= 1 then
    return index
  end

  local data = M.load_data()
  local list

  if item_type == "group" then
    if not path or path == "" then
      list = data.groups
    else
      local parent = M.find_group(data, path)
      list = parent and parent.children or nil
    end
  else
    local group = M.find_group(data, path)
    list = group and group.items or nil
  end

  if not list or index > #list then
    return index
  end

  -- Swap with previous
  list[index], list[index - 1] = list[index - 1], list[index]
  list[index].order = index
  list[index - 1].order = index - 1

  M.save_data(data)
  return index - 1
end

---Reorder an item down
---@param item_type "group"|"item"
---@param path string Group path (for items) or group's parent path (for groups)
---@param index number Current 1-based index
---@return number new_index New position
function M.reorder_down(item_type, path, index)
  local data = M.load_data()
  local list

  if item_type == "group" then
    if not path or path == "" then
      list = data.groups
    else
      local parent = M.find_group(data, path)
      list = parent and parent.children or nil
    end
  else
    local group = M.find_group(data, path)
    list = group and group.items or nil
  end

  if not list or index >= #list then
    return index
  end

  -- Swap with next
  list[index], list[index + 1] = list[index + 1], list[index]
  list[index].order = index
  list[index + 1].order = index + 1

  M.save_data(data)
  return index + 1
end

-- ============================================================================
-- UI State Helpers
-- ============================================================================

---Check if a group is expanded
---@param ui_state FavdirUIState
---@param group_path string
---@return boolean
function M.is_expanded(ui_state, group_path)
  return vim.tbl_contains(ui_state.expanded_groups, group_path)
end

---Toggle group expansion
---@param group_path string
---@return boolean new_state
function M.toggle_expanded(group_path)
  local ui_state = M.load_ui_state()

  if M.is_expanded(ui_state, group_path) then
    ui_state.expanded_groups = vim.tbl_filter(function(p)
      return p ~= group_path
    end, ui_state.expanded_groups)
    M.save_ui_state(ui_state)
    return false
  else
    table.insert(ui_state.expanded_groups, group_path)
    M.save_ui_state(ui_state)
    return true
  end
end

return M
