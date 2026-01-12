---@module favdir.state.stat_cache
---Async stat cache for file metadata with TTL support

local M = {}

-- ============================================================================
-- Type Definitions
-- ============================================================================

---@class StatCacheEntry
---@field stat table? The stat result from vim.loop.fs_stat
---@field timestamp number When this entry was cached (os.time())
---@field pending boolean Whether a fetch is in progress

---@class StatCache
---@field entries table<string, StatCacheEntry> Cached stat entries by path
---@field ttl number Time-to-live in seconds (default 30)
---@field pending_callbacks table<string, function[]> Callbacks waiting for pending fetches

-- ============================================================================
-- Cache State
-- ============================================================================

---@type StatCache
local cache = {
  entries = {},
  ttl = 30,
  pending_callbacks = {},
}

-- ============================================================================
-- Cache Operations
-- ============================================================================

---Check if a cache entry is still valid
---@param entry StatCacheEntry
---@return boolean
local function is_valid(entry)
  if not entry then
    return false
  end
  return (os.time() - entry.timestamp) < cache.ttl
end

---Get cached stat for a path (synchronous, returns nil if not cached)
---@param path string
---@return table? stat The cached stat or nil
function M.get(path)
  local entry = cache.entries[path]
  if entry and is_valid(entry) and not entry.pending then
    return entry.stat
  end
  return nil
end

---Check if a path has a valid cache entry
---@param path string
---@return boolean
function M.has(path)
  local entry = cache.entries[path]
  return entry ~= nil and is_valid(entry) and not entry.pending
end

---Set cached stat for a path
---@param path string
---@param stat table?
function M.set(path, stat)
  cache.entries[path] = {
    stat = stat,
    timestamp = os.time(),
    pending = false,
  }
end

---Clear the entire cache
function M.clear()
  cache.entries = {}
  cache.pending_callbacks = {}
end

---Clear cache entries for paths matching a pattern
---@param pattern string? Lua pattern to match paths (nil clears all)
function M.invalidate(pattern)
  if not pattern then
    M.clear()
    return
  end
  for path in pairs(cache.entries) do
    if path:match(pattern) then
      cache.entries[path] = nil
    end
  end
end

---Set the TTL for cache entries
---@param seconds number
function M.set_ttl(seconds)
  cache.ttl = seconds
end

-- ============================================================================
-- Async Stat Fetching
-- ============================================================================

---Fetch stat for a single path asynchronously
---@param path string
---@param callback fun(stat: table?)
function M.fetch_async(path, callback)
  -- Check cache first
  local entry = cache.entries[path]
  if entry and is_valid(entry) then
    if entry.pending then
      -- Already fetching, queue callback
      cache.pending_callbacks[path] = cache.pending_callbacks[path] or {}
      table.insert(cache.pending_callbacks[path], callback)
      return
    else
      -- Use cached value
      vim.schedule(function()
        callback(entry.stat)
      end)
      return
    end
  end

  -- Mark as pending
  cache.entries[path] = {
    stat = nil,
    timestamp = os.time(),
    pending = true,
  }
  cache.pending_callbacks[path] = { callback }

  -- Async stat call
  vim.loop.fs_stat(path, function(err, stat)
    vim.schedule(function()
      -- Update cache
      cache.entries[path] = {
        stat = err and nil or stat,
        timestamp = os.time(),
        pending = false,
      }

      -- Call all pending callbacks
      local callbacks = cache.pending_callbacks[path] or {}
      cache.pending_callbacks[path] = nil
      for _, cb in ipairs(callbacks) do
        cb(cache.entries[path].stat)
      end
    end)
  end)
end

---Prefetch stats for multiple paths asynchronously
---@param paths string[] List of paths to fetch
---@param on_complete fun() Called when all paths have been fetched
---@param on_progress fun(completed: number, total: number)? Optional progress callback
function M.prefetch_async(paths, on_complete, on_progress)
  if #paths == 0 then
    vim.schedule(on_complete)
    return
  end

  local total = #paths
  local completed = 0
  local reported_complete = false

  local function check_complete()
    if completed >= total and not reported_complete then
      reported_complete = true
      vim.schedule(on_complete)
    end
  end

  for _, path in ipairs(paths) do
    -- Check if already cached
    if M.has(path) then
      completed = completed + 1
      if on_progress then
        vim.schedule(function()
          on_progress(completed, total)
        end)
      end
      check_complete()
    else
      M.fetch_async(path, function(_)
        completed = completed + 1
        if on_progress then
          vim.schedule(function()
            on_progress(completed, total)
          end)
        end
        check_complete()
      end)
    end
  end
end

-- ============================================================================
-- Synchronous Fallback (uses cache if available)
-- ============================================================================

---Get stat synchronously, using cache if available, otherwise blocking call
---@param path string
---@return table? stat
function M.get_sync(path)
  -- Check cache first
  local cached = M.get(path)
  if cached then
    return cached
  end

  -- Blocking fallback
  local ok, stat = pcall(vim.loop.fs_stat, path)
  local result = ok and stat or nil

  -- Cache the result
  M.set(path, result)

  return result
end

return M
