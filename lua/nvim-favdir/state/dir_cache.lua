---@module favdir.state.dir_cache
---Session-only directory contents cache for favdir
---Caches raw readdir results to avoid repeated filesystem reads (especially on network drives)

local M = {}

---@class DirCacheEntry
---@field entries string[] Raw readdir results
---@field timestamp number Cache time (os.clock)

---@type table<string, DirCacheEntry>
local cache = {}

---Normalize a path for use as cache key
---@param dir_path string
---@return string
local function normalize(dir_path)
  return vim.fn.fnamemodify(dir_path, ':p')
end

---Get cached entries for a directory path
---@param dir_path string
---@return string[]? entries Raw readdir results, or nil if not cached
function M.get(dir_path)
  local key = normalize(dir_path)
  local entry = cache[key]
  if entry then
    return entry.entries
  end
  return nil
end

---Cache entries for a directory path
---@param dir_path string
---@param entries string[] Raw readdir results
function M.set(dir_path, entries)
  local key = normalize(dir_path)
  cache[key] = {
    entries = entries,
    timestamp = os.clock(),
  }
end

---Invalidate cache for a specific path
---@param dir_path string
function M.invalidate(dir_path)
  local key = normalize(dir_path)
  cache[key] = nil
end

---Invalidate cache entries for subdirectories of a path
---Keeps the path itself cached, clears children to bound memory
---@param dir_path string
function M.invalidate_children(dir_path)
  local prefix = normalize(dir_path)
  local to_remove = {}
  for key, _ in pairs(cache) do
    -- Remove entries that are children (start with prefix but are not the prefix itself)
    if key ~= prefix and vim.startswith(key, prefix) then
      table.insert(to_remove, key)
    end
  end
  for _, key in ipairs(to_remove) do
    cache[key] = nil
  end
end

---Clear the entire cache
function M.clear()
  cache = {}
end

return M
