---@module favdir.state.sorting
---Sorting and reordering operations for favdir

local M = {}

local data_module = require("favdir.state.data")
local groups_module = require("favdir.state.groups")

-- ============================================================================
-- Sorting Functions
-- ============================================================================

---Sort groups at a given level
---@param parent_path string? Parent path (nil for root)
---@param mode "custom"|"alpha"
function M.sort_groups(parent_path, mode)
  local data = data_module.load_data()
  local groups

  if not parent_path or parent_path == "" then
    groups = data.groups
  else
    local parent = groups_module.find_group(data, parent_path)
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

  data_module.save_data(data)
end

---Sort items in a group (persists order to data file)
---@param group_path string Group path
---@param mode "custom"|"alpha"|"type"
function M.sort_items(group_path, mode)
  local data = data_module.load_data()
  local group = groups_module.find_group(data, group_path)

  if not group then return end

  if mode == "alpha" then
    table.sort(group.items, function(a, b)
      local name_a = vim.fn.fnamemodify(a.path, ':t'):lower()
      local name_b = vim.fn.fnamemodify(b.path, ':t'):lower()
      return name_a < name_b
    end)
  elseif mode == "type" then
    table.sort(group.items, function(a, b)
      if a.type ~= b.type then return a.type == "dir" end
      local name_a = vim.fn.fnamemodify(a.path, ':t'):lower()
      local name_b = vim.fn.fnamemodify(b.path, ':t'):lower()
      return name_a < name_b
    end)
  else
    table.sort(group.items, function(a, b)
      return (a.order or 0) < (b.order or 0)
    end)
  end

  -- Update order numbers
  for i, item in ipairs(group.items) do
    item.order = i
  end

  data_module.save_data(data)
end

-- ============================================================================
-- Reordering Functions
-- ============================================================================

---Reorder an item up
---@param item_type "group"|"item"
---@param path string Group path (for items) or group's parent path (for groups)
---@param index number Current 1-based index
---@return number new_index New position
function M.reorder_up(item_type, path, index)
  if index <= 1 then
    return index
  end

  local data = data_module.load_data()
  local list

  if item_type == "group" then
    if not path or path == "" then
      list = data.groups
    else
      local parent = groups_module.find_group(data, path)
      list = parent and parent.children or nil
    end
  else
    local group = groups_module.find_group(data, path)
    list = group and group.items or nil
  end

  if not list or index > #list then
    return index
  end

  -- Swap with previous
  list[index], list[index - 1] = list[index - 1], list[index]
  list[index].order = index
  list[index - 1].order = index - 1

  data_module.save_data(data)
  return index - 1
end

---Reorder an item down
---@param item_type "group"|"item"
---@param path string Group path (for items) or group's parent path (for groups)
---@param index number Current 1-based index
---@return number new_index New position
function M.reorder_down(item_type, path, index)
  local data = data_module.load_data()
  local list

  if item_type == "group" then
    if not path or path == "" then
      list = data.groups
    else
      local parent = groups_module.find_group(data, path)
      list = parent and parent.children or nil
    end
  else
    local group = groups_module.find_group(data, path)
    list = group and group.items or nil
  end

  if not list or index >= #list then
    return index
  end

  -- Swap with next
  list[index], list[index + 1] = list[index + 1], list[index]
  list[index].order = index
  list[index + 1].order = index + 1

  data_module.save_data(data)
  return index + 1
end

return M
