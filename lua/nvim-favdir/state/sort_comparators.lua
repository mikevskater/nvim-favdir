---@module favdir.state.sort_comparators
---Unified sorting logic for favdir

local M = {}

local stat_cache = require("nvim-favdir.state.stat_cache")

-- ============================================================================
-- Type Definitions
-- ============================================================================

---@alias SortMode "custom"|"name"|"alpha"|"created"|"modified"|"size"|"type"

---@class SortOptions
---@field mode SortMode
---@field ascending boolean
---@field get_path? fun(item: any): string Get filesystem path for stat operations
---@field get_type? fun(item: any): string Get type ("dir", "file", "parent", etc.)
---@field get_order? fun(item: any): number Get order field for custom sorting
---@field get_name? fun(item: any): string Get name for alphabetical sorting

-- ============================================================================
-- File Stats Helpers
-- ============================================================================

---Get file stats using cache (async-populated, sync fallback)
---@param path string
---@return table? stat
local function get_stat(path)
  return stat_cache.get_sync(path)
end

---Get creation time from path
---@param path string
---@return number timestamp (0 if unavailable)
local function get_created_time(path)
  local stat = get_stat(path)
  if stat and stat.birthtime then
    return stat.birthtime.sec or 0
  end
  return 0
end

---Get modification time from path
---@param path string
---@return number timestamp (0 if unavailable)
local function get_modified_time(path)
  local stat = get_stat(path)
  if stat and stat.mtime then
    return stat.mtime.sec or 0
  end
  return 0
end

---Get file size from path
---@param path string
---@param item_type string? Item type ("dir" returns 0)
---@return number size (0 for directories or unavailable)
local function get_size(path, item_type)
  if item_type == "dir" then
    return 0
  end
  local stat = get_stat(path)
  if stat then
    return stat.size or 0
  end
  return 0
end

-- ============================================================================
-- Default Accessors
-- ============================================================================

---Default accessor for FavdirItem path
---@param item FavdirItem
---@return string
local function default_get_path(item)
  return item.path or ""
end

---Default accessor for item type
---@param item table
---@return string
local function default_get_type(item)
  return item.type or "file"
end

---Default accessor for order field
---@param item table
---@return number
local function default_get_order(item)
  return item.order or 0
end

---Default accessor for name (extracts filename from path)
---@param item table
---@return string
local function default_get_name(item)
  if item.name then
    return item.name
  end
  if item.path then
    return vim.fn.fnamemodify(item.path, ':t')
  end
  return ""
end

-- ============================================================================
-- Comparator Factory
-- ============================================================================

---Create a comparator function for sorting
---@param opts SortOptions
---@return fun(a: any, b: any): boolean
function M.create_comparator(opts)
  local mode = opts.mode or "custom"
  local ascending = opts.ascending ~= false -- default to true
  local get_path = opts.get_path or default_get_path
  local get_type = opts.get_type or default_get_type
  local get_order = opts.get_order or default_get_order
  local get_name = opts.get_name or default_get_name

  return function(a, b)
    local result

    if mode == "custom" then
      result = get_order(a) < get_order(b)

    elseif mode == "name" or mode == "alpha" then
      local name_a = get_name(a):lower()
      local name_b = get_name(b):lower()
      result = name_a < name_b

    elseif mode == "created" then
      local time_a = get_created_time(get_path(a))
      local time_b = get_created_time(get_path(b))
      -- Newest first by default (so we compare > not <)
      result = time_a > time_b

    elseif mode == "modified" then
      local time_a = get_modified_time(get_path(a))
      local time_b = get_modified_time(get_path(b))
      -- Newest first by default
      result = time_a > time_b

    elseif mode == "size" then
      local size_a = get_size(get_path(a), get_type(a))
      local size_b = get_size(get_path(b), get_type(b))
      -- Largest first by default
      result = size_a > size_b

    elseif mode == "type" then
      -- Directories first, then files, alphabetically within each
      local type_a = get_type(a)
      local type_b = get_type(b)
      if type_a ~= type_b then
        result = type_a == "dir"
      else
        local name_a = get_name(a):lower()
        local name_b = get_name(b):lower()
        result = name_a < name_b
      end

    else
      -- Fallback to custom
      result = get_order(a) < get_order(b)
    end

    -- Reverse if descending
    if not ascending then
      return not result
    end
    return result
  end
end

---Sort items in place using a comparator
---@param items table[]
---@param opts SortOptions
function M.sort(items, opts)
  if not items or #items == 0 then
    return
  end
  local comparator = M.create_comparator(opts)
  table.sort(items, comparator)
end

-- ============================================================================
-- Pre-configured Comparator Factories
-- ============================================================================

---Create comparator for FavdirItem[] (group items)
---@param mode SortMode
---@param ascending boolean?
---@return fun(a: FavdirItem, b: FavdirItem): boolean
function M.item_comparator(mode, ascending)
  return M.create_comparator({
    mode = mode,
    ascending = ascending ~= false,
    get_path = function(item) return item.path or "" end,
    get_type = function(item) return item.type or "file" end,
    get_order = function(item) return item.order or 0 end,
    get_name = function(item)
      if item.path then
        return vim.fn.fnamemodify(item.path, ':t')
      end
      return ""
    end,
  })
end

---Create comparator for FavdirGroup[] (groups and children)
---@param mode "custom"|"alpha"
---@param ascending boolean?
---@return fun(a: FavdirGroup, b: FavdirGroup): boolean
function M.group_comparator(mode, ascending)
  return M.create_comparator({
    mode = mode,
    ascending = ascending ~= false,
    get_path = function(_) return "" end, -- Groups don't have filesystem paths
    get_type = function(_) return "group" end,
    get_order = function(group) return group.order or 0 end,
    get_name = function(group) return group.name or "" end,
  })
end

---Create comparator for directory entries (with parent ".." always first)
---@param mode SortMode
---@param ascending boolean?
---@return fun(a: table, b: table): boolean
function M.directory_comparator(mode, ascending)
  local base_comparator = M.create_comparator({
    mode = mode,
    ascending = ascending ~= false,
    get_path = function(item) return item.path or "" end,
    get_type = function(item) return item.type or "file" end,
    get_order = function(item) return item.order or 0 end,
    get_name = function(item) return item.name or "" end,
  })

  -- Wrap to ensure parent entry always comes first
  return function(a, b)
    if a.type == "parent" then return true end
    if b.type == "parent" then return false end
    return base_comparator(a, b)
  end
end

---Create comparator for mixed children (groups and dir_links together)
---Both share the same order space
---@param ascending boolean?
---@return fun(a: table, b: table): boolean
function M.mixed_children_comparator(ascending)
  local asc = ascending ~= false
  return function(a, b)
    local order_a = a.order or 0
    local order_b = b.order or 0
    if asc then
      return order_a < order_b
    else
      return order_a > order_b
    end
  end
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

---Renumber order fields after sorting (makes order sequential: 1, 2, 3, ...)
---@param items table[]
function M.renumber_order(items)
  if not items then return end
  for i, item in ipairs(items) do
    item.order = i
  end
end

---Sort and renumber in one operation
---@param items table[]
---@param opts SortOptions
function M.sort_and_renumber(items, opts)
  M.sort(items, opts)
  M.renumber_order(items)
end

-- ============================================================================
-- Stat Cache Helpers
-- ============================================================================

---Check if a sort mode requires filesystem stat calls
---@param mode SortMode
---@return boolean
function M.mode_requires_stat(mode)
  return mode == "modified" or mode == "created" or mode == "size"
end

---Collect paths from items for prefetching
---@param items table[] Items with path field
---@param get_path? fun(item: any): string Optional path accessor
---@return string[]
function M.collect_paths(items, get_path)
  local paths = {}
  local accessor = get_path or function(item) return item.path or "" end
  for _, item in ipairs(items) do
    local path = accessor(item)
    if path and path ~= "" then
      table.insert(paths, path)
    end
  end
  return paths
end

---Prefetch stats for items asynchronously
---@param items table[] Items with path field
---@param on_complete fun() Called when prefetch is complete
---@param on_progress? fun(completed: number, total: number) Optional progress callback
---@param get_path? fun(item: any): string Optional path accessor
function M.prefetch_stats(items, on_complete, on_progress, get_path)
  local paths = M.collect_paths(items, get_path)
  stat_cache.prefetch_async(paths, on_complete, on_progress)
end

---Clear the stat cache
function M.clear_cache()
  stat_cache.clear()
end

---Invalidate cache entries matching a pattern
---@param pattern string? Lua pattern (nil clears all)
function M.invalidate_cache(pattern)
  stat_cache.invalidate(pattern)
end

return M
