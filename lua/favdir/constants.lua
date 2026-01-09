---@module favdir.constants
---Centralized constants and enums for favdir

local M = {}

-- ============================================================================
-- Item Types
-- ============================================================================

---@enum ItemType
M.ITEM_TYPE = {
  GROUP = "group",
  DIR_LINK = "dir_link",
  FILE = "file",
  DIR = "dir",
  PARENT = "parent",
}

-- ============================================================================
-- Sort Modes
-- ============================================================================

---@enum SortMode
M.SORT_MODE = {
  CUSTOM = "custom",
  ALPHA = "alpha",
  NAME = "name",
  TYPE = "type",
  CREATED = "created",
  MODIFIED = "modified",
  SIZE = "size",
}

---Left panel (groups) sort modes
M.LEFT_SORT_MODES = { M.SORT_MODE.CUSTOM, M.SORT_MODE.ALPHA }

---Right panel (items) sort modes
M.RIGHT_SORT_MODES = {
  M.SORT_MODE.CUSTOM,
  M.SORT_MODE.NAME,
  M.SORT_MODE.CREATED,
  M.SORT_MODE.MODIFIED,
  M.SORT_MODE.SIZE,
  M.SORT_MODE.TYPE,
}

---Directory view sort modes (no custom order for filesystem)
M.DIR_SORT_MODES = {
  M.SORT_MODE.NAME,
  M.SORT_MODE.CREATED,
  M.SORT_MODE.MODIFIED,
  M.SORT_MODE.SIZE,
  M.SORT_MODE.TYPE,
}

-- ============================================================================
-- Panels
-- ============================================================================

---@enum Panel
M.PANEL = {
  GROUPS = "groups",
  ITEMS = "items",
}

-- ============================================================================
-- Selection Types
-- ============================================================================

---@enum SelectionType
M.SELECTION_TYPE = {
  GROUP = "group",
  DIR_LINK = "dir_link",
}

-- ============================================================================
-- Default Values
-- ============================================================================

M.DEFAULTS = {
  LEFT_SORT_MODE = M.SORT_MODE.CUSTOM,
  RIGHT_SORT_MODE = M.SORT_MODE.CUSTOM,
  DIR_SORT_MODE = M.SORT_MODE.TYPE,
  SELECTION_TYPE = M.SELECTION_TYPE.GROUP,
  SORT_ASCENDING = true,
}

return M
