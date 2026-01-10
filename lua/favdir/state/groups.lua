---@module favdir.state.groups
---Group management operations for favdir

local M = {}

local data_module = require("favdir.state.data")
local logger = require("favdir.logger")
local utils = require("favdir.state.utils")
local path_utils = require("favdir.path_utils")

-- ============================================================================
-- Group Lookup
-- ============================================================================

---Find a group by path (e.g., "Work.Projects.Active")
---@param data FavdirData
---@param group_path string Dot-separated path
---@return FavdirGroup?, FavdirGroup[]? parent_list The group and its parent list
function M.find_group(data, group_path)
  if not group_path or group_path == "" then
    return nil, nil
  end

  local parts = path_utils.split(group_path)
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
    local parent_path = path_utils.get_parent_path(group_path)
    local parent = M.find_group(data, parent_path)
    if parent then
      return group, parent.children
    end
  end

  return group, nil
end

---Get flat list of all group paths
---@return string[]
function M.get_group_list()
  local data = data_module.load_data()
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
-- Group CRUD Operations
-- ============================================================================

---Add a new group
---@param parent_path string? Parent group path (nil for root)
---@param name string Group name
---@return boolean success
---@return string? error_message
function M.add_group(parent_path, name)
  if not name or name == "" then
    return false, "Group name cannot be empty"
  end

  local data = data_module.load_data()
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
    order = utils.get_next_order(target_list),
    children = {},
  })

  data_module.save_data(data)
  logger.debug("Added group: %s (parent: %s)", name, parent_path or "root")
  return true, nil
end

---Remove a group
---@param group_path string Group path to remove
---@return boolean success
---@return string? error_message
function M.remove_group(group_path)
  local data = data_module.load_data()
  local group, parent_list = M.find_group(data, group_path)

  if not group or not parent_list then
    return false, "Group not found"
  end

  -- Check if protected
  local config = data_module.get_config()
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
  local ui_state = data_module.load_ui_state()
  ui_state.expanded_groups = vim.tbl_filter(function(path)
    return not vim.startswith(path, group_path)
  end, ui_state.expanded_groups)
  data_module.save_ui_state(ui_state)

  data_module.save_data(data)
  logger.debug("Removed group: %s", group_path)
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

  local data = data_module.load_data()
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
  local ui_state = data_module.load_ui_state()
  local new_path = path_utils.rename_last_segment(group_path, new_name)
  ui_state.expanded_groups = path_utils.update_paths_after_rename(
    ui_state.expanded_groups,
    group_path,
    new_path
  )
  data_module.save_ui_state(ui_state)

  data_module.save_data(data)
  return true, nil
end

---Move a group to a new parent
---@param group_path string Group path to move
---@param new_parent_path string New parent path (empty string for root level)
---@return boolean success
---@return string? error_message
function M.move_group(group_path, new_parent_path)
  if not group_path or group_path == "" then
    return false, "No group specified"
  end

  local data = data_module.load_data()
  local group, source_list = M.find_group(data, group_path)

  if not group or not source_list then
    return false, "Group not found"
  end

  -- Check if protected
  local config = data_module.get_config()
  if config and vim.tbl_contains(config.protected_groups, group.name) then
    return false, "Cannot move protected group"
  end

  -- Find target parent list
  local target_list
  if new_parent_path == "" then
    target_list = data.groups
  else
    local parent_group = M.find_group(data, new_parent_path)
    if not parent_group then
      return false, "Target parent not found"
    end
    -- Ensure children array exists
    parent_group.children = parent_group.children or {}
    target_list = parent_group.children
  end

  -- Prevent circular reference: can't move a group into itself or its children
  if new_parent_path ~= "" and (new_parent_path == group_path or vim.startswith(new_parent_path, group_path .. ".")) then
    return false, "Cannot move group into itself or its children"
  end

  -- Check for duplicate name at target level
  for _, g in ipairs(target_list) do
    if g.name == group.name then
      return false, "A group with this name already exists at target location"
    end
  end

  -- Remove from source list
  for i, g in ipairs(source_list) do
    if g == group then
      table.remove(source_list, i)
      break
    end
  end

  -- Add to target list with new order
  group.order = #target_list + 1
  table.insert(target_list, group)

  -- Update UI state expanded_groups paths
  local ui_state = data_module.load_ui_state()
  local new_expanded = {}
  local new_path = new_parent_path == "" and group.name or (new_parent_path .. "." .. group.name)

  for _, path in ipairs(ui_state.expanded_groups) do
    if path == group_path then
      -- Update this exact path
      table.insert(new_expanded, new_path)
    elseif vim.startswith(path, group_path .. ".") then
      -- Update child paths
      local suffix = path:sub(#group_path + 2)
      table.insert(new_expanded, new_path .. "." .. suffix)
    else
      table.insert(new_expanded, path)
    end
  end
  ui_state.expanded_groups = new_expanded

  -- Update last_selected_group if it was the moved group or a child
  if ui_state.last_selected_group == group_path then
    ui_state.last_selected_group = new_path
  elseif ui_state.last_selected_group and vim.startswith(ui_state.last_selected_group, group_path .. ".") then
    local suffix = ui_state.last_selected_group:sub(#group_path + 2)
    ui_state.last_selected_group = new_path .. "." .. suffix
  end

  data_module.save_ui_state(ui_state)
  data_module.save_data(data)
  return true, nil
end

return M
