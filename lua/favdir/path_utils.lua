---@module favdir.path_utils
---Utilities for manipulating dot-separated group paths

local M = {}

-- ============================================================================
-- Path Manipulation
-- ============================================================================

---Split a dot-separated path into segments
---@param path string Dot-separated path (e.g., "Work.Projects.Active")
---@return string[] segments Array of path segments
function M.split(path)
  if not path or path == "" then
    return {}
  end
  return vim.split(path, ".", { plain = true })
end

---Join path segments into a dot-separated path
---@param ... string Path segments to join
---@return string path Dot-separated path
function M.join(...)
  local segments = {}
  for _, seg in ipairs({ ... }) do
    if seg and seg ~= "" then
      table.insert(segments, seg)
    end
  end
  return table.concat(segments, ".")
end

---Get the parent path from a dot-separated group path
---@param group_path string Full path (e.g., "Work.Projects.Active")
---@return string parent_path Parent path (e.g., "Work.Projects"), empty string if at root
function M.get_parent_path(group_path)
  if not group_path or group_path == "" then
    return ""
  end

  local parts = M.split(group_path)
  if #parts <= 1 then
    return ""
  end

  return table.concat(vim.list_slice(parts, 1, #parts - 1), ".")
end

---Get the last segment (name) from a group path
---@param group_path string Full path (e.g., "Work.Projects.Active")
---@return string name Last segment (e.g., "Active"), empty string if path is empty
function M.get_name(group_path)
  if not group_path or group_path == "" then
    return ""
  end

  local parts = M.split(group_path)
  return parts[#parts] or ""
end

---Get the depth (number of segments) of a path
---@param group_path string Dot-separated path
---@return number depth Number of segments (0 for empty path)
function M.get_depth(group_path)
  if not group_path or group_path == "" then
    return 0
  end
  return #M.split(group_path)
end

-- ============================================================================
-- Path Relationships
-- ============================================================================

---Check if child_path is a descendant of parent_path
---@param parent_path string The potential parent path
---@param child_path string The potential child path
---@return boolean is_descendant True if child_path is under parent_path
function M.is_descendant(parent_path, child_path)
  if not parent_path or parent_path == "" then
    -- Everything is a descendant of root
    return child_path and child_path ~= ""
  end
  if not child_path or child_path == "" then
    return false
  end
  -- Child must start with parent path followed by a dot
  return vim.startswith(child_path, parent_path .. ".")
end

---Check if two paths are siblings (same parent)
---@param path1 string First path
---@param path2 string Second path
---@return boolean are_siblings True if paths share the same parent
function M.are_siblings(path1, path2)
  return M.get_parent_path(path1) == M.get_parent_path(path2)
end

-- ============================================================================
-- Path Updates
-- ============================================================================

---Update paths in a list after a rename operation
---Handles both exact matches and descendant paths
---@param paths string[] List of paths to update
---@param old_path string The path being renamed
---@param new_path string The new path
---@return string[] updated_paths New list with updated paths
function M.update_paths_after_rename(paths, old_path, new_path)
  if not paths then
    return {}
  end

  local updated = {}
  for _, path in ipairs(paths) do
    if path == old_path then
      -- Exact match - replace with new path
      table.insert(updated, new_path)
    elseif M.is_descendant(old_path, path) then
      -- Descendant - replace prefix
      local suffix = path:sub(#old_path + 2) -- +2 to skip the trailing dot
      table.insert(updated, new_path .. "." .. suffix)
    else
      -- No relation - keep as is
      table.insert(updated, path)
    end
  end
  return updated
end

---Build a new path after renaming the last segment
---@param old_path string The current full path
---@param new_name string The new name for the last segment
---@return string new_path The updated full path
function M.rename_last_segment(old_path, new_name)
  if not old_path or old_path == "" then
    return new_name or ""
  end

  local parts = M.split(old_path)
  parts[#parts] = new_name
  return table.concat(parts, ".")
end

---Build a new path when moving to a different parent
---@param name string The name of the item being moved
---@param new_parent_path string The new parent path (empty string for root)
---@return string new_path The full path after move
function M.build_moved_path(name, new_parent_path)
  if not new_parent_path or new_parent_path == "" then
    return name
  end
  return new_parent_path .. "." .. name
end

return M
