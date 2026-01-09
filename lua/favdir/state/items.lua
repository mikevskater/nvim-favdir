---@module favdir.state.items
---Item management operations for favdir

local M = {}

local data_module = require("favdir.state.data")
local groups_module = require("favdir.state.groups")
local logger = require("favdir.logger")

-- ============================================================================
-- Helper Functions
-- ============================================================================

---Get next order number for a list
---@param list FavdirItem[]
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

-- ============================================================================
-- Item CRUD Operations
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

  local data = data_module.load_data()
  local group = groups_module.find_group(data, group_path)

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

  data_module.save_data(data)
  logger.info("Added %s to %s", vim.fn.fnamemodify(abs_path, ':t'), group_path)
  return true, nil
end

---Remove an item from a group
---@param group_path string Group path
---@param item_index number 1-based index
---@return boolean success
---@return string? error_message
function M.remove_item(group_path, item_index)
  local data = data_module.load_data()
  local group = groups_module.find_group(data, group_path)

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

  data_module.save_data(data)
  return true, nil
end

---Move an item to another group
---@param from_group string Source group path
---@param item_index number 1-based index of item
---@param to_group string Target group path
---@return boolean success
---@return string? error_message
function M.move_item(from_group, item_index, to_group)
  local data = data_module.load_data()
  local source = groups_module.find_group(data, from_group)
  local target = groups_module.find_group(data, to_group)

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

  data_module.save_data(data)
  return true, nil
end

return M
