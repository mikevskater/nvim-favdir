---@module favdir.state.utils
---Shared utility functions for state management

local M = {}

-- ============================================================================
-- Order Management
-- ============================================================================

---Get next order number for a list of items with order field
---@param list table[] List of items with optional order field
---@return number next_order The next available order number
function M.get_next_order(list)
  if not list then return 1 end

  local max_order = 0
  for _, item in ipairs(list) do
    if item.order and item.order > max_order then
      max_order = item.order
    end
  end
  return max_order + 1
end

---Get next order for a group's children and dir_links combined
---Both children and dir_links share the same order space
---@param group FavdirGroup
---@return number next_order
function M.get_next_child_order(group)
  if not group then return 1 end

  local max_order = 0

  if group.children then
    for _, child in ipairs(group.children) do
      if child.order and child.order > max_order then
        max_order = child.order
      end
    end
  end

  if group.dir_links then
    for _, link in ipairs(group.dir_links) do
      if link.order and link.order > max_order then
        max_order = link.order
      end
    end
  end

  return max_order + 1
end

---Renumber order fields sequentially (1, 2, 3, ...)
---Useful after removing items to keep order fields contiguous
---@param list table[] List of items with order field
function M.renumber_order(list)
  if not list then return end

  for i, item in ipairs(list) do
    item.order = i
  end
end

---Swap two items in a list and update their order fields
---@param list table[] List containing the items
---@param idx1 number First index (1-based)
---@param idx2 number Second index (1-based)
---@return boolean success Whether the swap was performed
function M.swap_items(list, idx1, idx2)
  if not list then return false end
  if idx1 < 1 or idx1 > #list then return false end
  if idx2 < 1 or idx2 > #list then return false end
  if idx1 == idx2 then return false end

  -- Swap positions
  list[idx1], list[idx2] = list[idx2], list[idx1]

  -- Update order fields
  list[idx1].order = idx1
  list[idx2].order = idx2

  return true
end

-- ============================================================================
-- List Operations
-- ============================================================================

---Find an item in a list by a field value
---@generic T
---@param list T[] List to search
---@param field string Field name to match
---@param value any Value to find
---@return T? item The found item or nil
---@return number? index The index of the found item or nil
function M.find_by_field(list, field, value)
  if not list then return nil, nil end

  for i, item in ipairs(list) do
    if item[field] == value then
      return item, i
    end
  end
  return nil, nil
end

---Check if a list contains an item with a matching field value
---@param list table[] List to search
---@param field string Field name to match
---@param value any Value to find
---@return boolean exists
function M.contains(list, field, value)
  local item = M.find_by_field(list, field, value)
  return item ~= nil
end

---Remove an item from a list by index and renumber remaining items
---@param list table[] List to modify
---@param index number Index to remove (1-based)
---@return table? removed The removed item or nil
function M.remove_and_renumber(list, index)
  if not list then return nil end
  if index < 1 or index > #list then return nil end

  local removed = table.remove(list, index)
  M.renumber_order(list)
  return removed
end

return M
