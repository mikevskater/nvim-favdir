---@module favdir.state.dir_links
---Directory link management operations for favdir

local M = {}

local data_module = require("favdir.state.data")
local utils = require("favdir.state.utils")
local path_utils = require("favdir.path_utils")

-- Forward declaration for groups module to avoid circular dependency
-- Will be set via set_groups_module()
local groups_module

---Set the groups module reference (called by state/init.lua to avoid circular deps)
---@param module table
function M.set_groups_module(module)
  groups_module = module
end

-- ============================================================================
-- Directory Link Operations
-- ============================================================================

---Add a directory link to a group
---@param parent_path string Parent group path (empty string for root level)
---@param name string Display name for the dir_link
---@param dir_path string Absolute path to directory
---@return boolean success
---@return string? error_message
function M.add_dir_link(parent_path, name, dir_path)
  if not name or name == "" then
    return false, "Name cannot be empty"
  end

  if not dir_path or dir_path == "" then
    return false, "Directory path cannot be empty"
  end

  -- Validate directory exists
  if vim.fn.isdirectory(dir_path) ~= 1 then
    return false, "Directory does not exist: " .. dir_path
  end

  local data = data_module.load_data()
  local parent

  if parent_path == "" then
    -- Adding to root level - need to track in data.groups context
    -- For root level dir_links, we need a root-level dir_links array
    -- But current structure doesn't support root-level dir_links
    -- Dir_links must be children of a group
    return false, "Directory links must be added to a group, not root level"
  end

  if not groups_module then
    return false, "Groups module not initialized"
  end

  parent = groups_module.find_group(data, parent_path)
  if not parent then
    return false, "Parent group not found"
  end

  -- Initialize dir_links if needed
  parent.dir_links = parent.dir_links or {}

  -- Check for duplicate name in dir_links
  for _, link in ipairs(parent.dir_links) do
    if link.name == name then
      return false, "A directory link with this name already exists"
    end
  end

  -- Check for duplicate name in children
  if parent.children then
    for _, child in ipairs(parent.children) do
      if child.name == name then
        return false, "A group with this name already exists"
      end
    end
  end

  -- Add the dir_link
  table.insert(parent.dir_links, {
    name = name,
    path = vim.fn.fnamemodify(dir_path, ':p'),
    order = utils.get_next_child_order(parent),
  })

  data_module.save_data(data)
  return true, nil
end

---Remove a directory link from a group
---@param parent_path string Parent group path
---@param name string Name of the dir_link to remove
---@return boolean success
---@return string? error_message
function M.remove_dir_link(parent_path, name)
  if not parent_path or parent_path == "" then
    return false, "Parent path is required"
  end

  if not groups_module then
    return false, "Groups module not initialized"
  end

  local data = data_module.load_data()
  local parent = groups_module.find_group(data, parent_path)

  if not parent then
    return false, "Parent group not found"
  end

  if not parent.dir_links then
    return false, "Directory link not found"
  end

  -- Find and remove
  for i, link in ipairs(parent.dir_links) do
    if link.name == name then
      table.remove(parent.dir_links, i)
      data_module.save_data(data)
      return true, nil
    end
  end

  return false, "Directory link not found"
end

---Find a directory link by full path (e.g., "Work.MyDocs" where MyDocs is a dir_link)
---@param data FavdirData
---@param link_path string Dot-separated path ending with dir_link name
---@return FavdirDirLink? link
---@return FavdirGroup? parent
function M.find_dir_link(data, link_path)
  if not link_path or link_path == "" then
    return nil, nil
  end

  local depth = path_utils.get_depth(link_path)
  if depth < 2 then
    return nil, nil
  end

  local parent_path = path_utils.get_parent_path(link_path)
  local link_name = path_utils.get_name(link_path)

  if not groups_module then
    return nil, nil
  end

  local parent = groups_module.find_group(data, parent_path)
  if not parent or not parent.dir_links then
    return nil, nil
  end

  for _, link in ipairs(parent.dir_links) do
    if link.name == link_name then
      return link, parent
    end
  end

  return nil, nil
end

return M
