---@module favdir.state.items
---Item management operations for favdir

local M = {}

local data_module = require("nvim-favdir.state.data")
local groups_module = require("nvim-favdir.state.groups")
local logger = require("nvim-favdir.logger")
local utils = require("nvim-favdir.state.utils")

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
    order = utils.get_next_order(group.items),
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
  utils.renumber_order(group.items)

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

  item.order = utils.get_next_order(target.items)
  table.insert(target.items, item)
  utils.renumber_order(source.items)

  data_module.save_data(data)
  return true, nil
end

---Set or clear the display name (nickname) for an item
---@param group_path string Group path
---@param item_path string Path of the item to rename
---@param display_name string? Display name (nil or empty to clear)
---@return boolean success
---@return string? error_message
function M.set_display_name(group_path, item_path, display_name)
  local data = data_module.load_data()
  local group = groups_module.find_group(data, group_path)

  if not group then
    return false, "Group not found"
  end

  for _, item in ipairs(group.items) do
    if item.path == item_path then
      -- Clear display_name if empty or matches the filename
      local filename = vim.fn.fnamemodify(item.path:gsub("[/\\]+$", ""), ':t')
      if not display_name or display_name == "" or display_name == filename then
        item.display_name = nil
      else
        item.display_name = display_name
      end
      data_module.save_data(data)
      return true, nil
    end
  end

  return false, "Item not found in group"
end

return M
