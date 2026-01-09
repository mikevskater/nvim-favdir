---@module favdir.logger
---Centralized logging and error handling system for favdir
---Provides consistent notifications, debug logging, and operation result wrappers

local M = {}

-- ============================================================================
-- Type Definitions
-- ============================================================================

---@enum LogLevel
M.levels = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

---@class LoggerConfig
---@field debug_mode boolean Enable debug logging (default: false)
---@field log_to_file boolean Write logs to file (default: false)
---@field log_file string? Path to log file
---@field notify_prefix string Prefix for notifications (default: "favdir")
---@field min_level LogLevel Minimum level to log (default: INFO)

---@class OperationResult<T>
---@field ok boolean Whether the operation succeeded
---@field data T? The result data (if ok)
---@field error string? Error message (if not ok)

-- ============================================================================
-- Module State
-- ============================================================================

---@type LoggerConfig
local config = {
  debug_mode = false,
  log_to_file = false,
  log_file = nil,
  notify_prefix = "favdir",
  min_level = M.levels.INFO,
}

-- Log level names for display
local level_names = {
  [M.levels.DEBUG] = "DEBUG",
  [M.levels.INFO] = "INFO",
  [M.levels.WARN] = "WARN",
  [M.levels.ERROR] = "ERROR",
}

-- Map log levels to vim.log.levels
local vim_levels = {
  [M.levels.DEBUG] = vim.log.levels.DEBUG,
  [M.levels.INFO] = vim.log.levels.INFO,
  [M.levels.WARN] = vim.log.levels.WARN,
  [M.levels.ERROR] = vim.log.levels.ERROR,
}

-- ============================================================================
-- Internal Functions
-- ============================================================================

---Format a log message with optional arguments
---@param msg string
---@param ... any
---@return string
local function format_message(msg, ...)
  local args = { ... }
  if #args > 0 then
    local ok, formatted = pcall(string.format, msg, ...)
    if ok then
      return formatted
    end
  end
  return msg
end

---Write to log file if enabled
---@param level LogLevel
---@param msg string
local function write_to_file(level, msg)
  if not config.log_to_file or not config.log_file then
    return
  end

  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local level_name = level_names[level] or "UNKNOWN"
  local line = string.format("[%s] [%s] %s\n", timestamp, level_name, msg)

  local file = io.open(config.log_file, "a")
  if file then
    file:write(line)
    file:close()
  end
end

---Core logging function
---@param level LogLevel
---@param msg string
---@param ... any
local function log(level, msg, ...)
  -- Check minimum level
  if level < config.min_level then
    return
  end

  -- Debug messages only show when debug_mode is enabled
  if level == M.levels.DEBUG and not config.debug_mode then
    return
  end

  local formatted = format_message(msg, ...)

  -- Write to file if enabled
  write_to_file(level, formatted)

  -- Notify user (skip DEBUG unless in debug_mode)
  if level >= M.levels.INFO or config.debug_mode then
    local prefix = config.notify_prefix
    local display_msg = formatted

    -- Add level prefix for debug messages
    if level == M.levels.DEBUG then
      display_msg = "[DEBUG] " .. formatted
    end

    vim.notify(prefix .. ": " .. display_msg, vim_levels[level])
  end
end

-- ============================================================================
-- Public API - Configuration
-- ============================================================================

---Initialize the logger with configuration
---@param opts LoggerConfig?
function M.init(opts)
  if opts then
    config = vim.tbl_deep_extend("force", config, opts)
  end

  -- Set min_level based on debug_mode if not explicitly set
  if opts and opts.debug_mode and not opts.min_level then
    config.min_level = M.levels.DEBUG
  end

  -- Setup log file path if logging enabled but no path set
  if config.log_to_file and not config.log_file then
    config.log_file = vim.fn.stdpath('data') .. '/favdir.log'
  end
end

---Check if debug mode is enabled
---@return boolean
function M.is_debug()
  return config.debug_mode
end

---Enable or disable debug mode at runtime
---@param enabled boolean
function M.set_debug(enabled)
  config.debug_mode = enabled
  if enabled then
    config.min_level = M.levels.DEBUG
  else
    config.min_level = M.levels.INFO
  end
end

-- ============================================================================
-- Public API - Logging Functions
-- ============================================================================

---Log a debug message (only shown when debug_mode is enabled)
---@param msg string
---@param ... any Format arguments
function M.debug(msg, ...)
  log(M.levels.DEBUG, msg, ...)
end

---Log an info message
---@param msg string
---@param ... any Format arguments
function M.info(msg, ...)
  log(M.levels.INFO, msg, ...)
end

---Log a warning message
---@param msg string
---@param ... any Format arguments
function M.warn(msg, ...)
  log(M.levels.WARN, msg, ...)
end

---Log an error message
---@param msg string
---@param ... any Format arguments
function M.error(msg, ...)
  log(M.levels.ERROR, msg, ...)
end

---Log an error with stack trace (for debugging)
---@param msg string
---@param ... any Format arguments
function M.error_with_trace(msg, ...)
  local formatted = format_message(msg, ...)
  local trace = debug.traceback("", 2)
  log(M.levels.ERROR, formatted .. "\n" .. trace)
end

-- ============================================================================
-- Public API - Operation Results
-- ============================================================================

---Create a successful result
---@generic T
---@param data T?
---@return OperationResult
function M.ok(data)
  return {
    ok = true,
    data = data,
    error = nil,
  }
end

---Create a failed result
---@param message string
---@return OperationResult
function M.err(message)
  return {
    ok = false,
    data = nil,
    error = message,
  }
end

---Unwrap a result, logging error if failed
---@generic T
---@param result OperationResult
---@param context string? Optional context for error message
---@return T? data
---@return string? error
function M.unwrap(result, context)
  if result.ok then
    return result.data, nil
  else
    local msg = result.error or "Unknown error"
    if context then
      msg = context .. ": " .. msg
    end
    M.error(msg)
    return nil, result.error
  end
end

---Check if result is ok, logging error if not (does not return data)
---@param result OperationResult
---@param context string? Optional context for error message
---@return boolean
function M.check(result, context)
  if result.ok then
    return true
  else
    local msg = result.error or "Unknown error"
    if context then
      msg = context .. ": " .. msg
    end
    M.error(msg)
    return false
  end
end

-- ============================================================================
-- Public API - Utility Functions
-- ============================================================================

---Wrap a function to catch errors and return OperationResult
---@generic T
---@param fn fun(...): T
---@param context string? Context for error messages
---@return fun(...): OperationResult
function M.wrap(fn, context)
  return function(...)
    local ok, result = pcall(fn, ...)
    if ok then
      return M.ok(result)
    else
      local msg = tostring(result)
      if context then
        msg = context .. ": " .. msg
      end
      if config.debug_mode then
        M.error_with_trace(msg)
      end
      return M.err(msg)
    end
  end
end

---Execute a function and handle errors gracefully
---@generic T
---@param fn fun(): T
---@param context string? Context for error messages
---@return T?
function M.try(fn, context)
  local ok, result = pcall(fn)
  if ok then
    return result
  else
    local msg = tostring(result)
    if context then
      msg = context .. ": " .. msg
    end
    M.error(msg)
    return nil
  end
end

---Log the start of an operation (debug level)
---@param operation string
function M.trace_start(operation)
  M.debug("Starting: %s", operation)
end

---Log the end of an operation (debug level)
---@param operation string
---@param success boolean?
function M.trace_end(operation, success)
  if success == false then
    M.debug("Failed: %s", operation)
  else
    M.debug("Completed: %s", operation)
  end
end

return M
