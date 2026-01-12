---@module favdir.ui.handlers.sorting
---Sorting and reordering handlers for favdir

local M = {}

local data_module = require("nvim-favdir.state.data")
local groups_module = require("nvim-favdir.state.groups")
local sorting_module = require("nvim-favdir.state.sorting")
local sort_comparators = require("nvim-favdir.state.sort_comparators")
local utils = require("nvim-favdir.ui.handlers.utils")
local logger = require("nvim-favdir.logger")
local path_utils = require("nvim-favdir.path_utils")
local constants = require("nvim-favdir.constants")

-- ============================================================================
-- Async Sort Helpers
-- ============================================================================

---Show loading indicator in statusline
---@param message string
local function show_loading(message)
  vim.api.nvim_echo({{ message, "WarningMsg" }}, false, {})
  vim.cmd("redraw")
end

---Clear loading indicator
local function clear_loading()
  vim.api.nvim_echo({{"", "Normal"}}, false, {})
end

---Collect paths from directory entries for prefetching
---@param dir_path string Directory path to read
---@return string[] paths List of file paths
local function collect_directory_paths(dir_path)
  local paths = {}
  local ok, entries = pcall(vim.fn.readdir, dir_path)
  if ok and entries then
    for _, entry in ipairs(entries) do
      table.insert(paths, dir_path .. "/" .. entry)
    end
  end
  return paths
end

---Handle sort with async prefetch for stat-requiring modes
---@param mp_state MultiPanelState
---@param paths string[] Paths to prefetch
---@param next_mode string The sort mode to apply
---@param panel string Panel to render after prefetch
---@param update_state fun(state: FavdirUIState) Function to update UI state
local function handle_async_sort(mp_state, paths, next_mode, panel, update_state)
  show_loading("Loading file info for " .. next_mode .. " sort...")

  sort_comparators.prefetch_stats(paths, function()
    clear_loading()
    utils.modify_ui_state(update_state)
    logger.info("Sorted: %s", next_mode)
    mp_state:render_panel(panel)
  end, function(completed, total)
    -- Optional: show progress for large directories
    if total > 20 then
      show_loading(string.format("Loading... %d/%d", completed, total))
    end
  end)
end

-- ============================================================================
-- Sort Handler
-- ============================================================================

---Handle Sort key
---@param mp_state MultiPanelState
function M.handle_sort(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused == constants.PANEL.GROUPS then
    local ui_state = data_module.load_ui_state()
    local modes = constants.LEFT_SORT_MODES
    local current = ui_state.left_sort_mode or constants.DEFAULTS.LEFT_SORT_MODE
    local idx = 1
    for i, m in ipairs(modes) do
      if m == current then
        idx = i
        break
      end
    end
    local next_mode = modes[(idx % #modes) + 1]

    utils.modify_ui_state(function(state)
      state.left_sort_mode = next_mode
    end)

    -- Apply sort to root groups
    sorting_module.sort_groups("", next_mode)

    logger.info("Groups sorted: %s", next_mode)
    mp_state:render_panel(constants.PANEL.GROUPS)
  else
    -- Check if we're viewing a dir_link (filesystem browser) vs group items
    if utils.is_directory_view() then
      -- Dir_link/directory view sorting modes
      local ui_state = data_module.load_ui_state()
      local modes = constants.DIR_SORT_MODES
      local current = ui_state.dir_sort_mode or constants.DEFAULTS.DIR_SORT_MODE
      local idx = 1
      for i, m in ipairs(modes) do
        if m == current then
          idx = i
          break
        end
      end
      local next_mode = modes[(idx % #modes) + 1]

      -- Check if new mode requires stat and we should prefetch async
      if sort_comparators.mode_requires_stat(next_mode) then
        local current_path = ui_state.dir_link_current_path or ui_state.last_selected_dir_link
        if current_path then
          local paths = collect_directory_paths(current_path)
          handle_async_sort(mp_state, paths, next_mode, constants.PANEL.ITEMS, function(state)
            state.dir_sort_mode = next_mode
          end)
          return
        end
      end

      -- Sync path for non-stat modes
      utils.modify_ui_state(function(state)
        state.dir_sort_mode = next_mode
      end)

      logger.info("Directory sorted: %s", next_mode)
      mp_state:render_panel(constants.PANEL.ITEMS)
    else
      -- Regular group items sorting
      -- Try to get group_path from element data first, then fallback to ui_state
      local element = mp_state:get_element_at_cursor()
      local group_path = utils.get_group_path(element)
      if not group_path then
        local ui_state = data_module.load_ui_state()
        group_path = ui_state.last_selected_group
      end

      if not group_path then
        logger.warn("Select a group first")
        return
      end

      local ui_state = data_module.load_ui_state()
      local modes = constants.RIGHT_SORT_MODES
      local current = ui_state.right_sort_mode or constants.DEFAULTS.RIGHT_SORT_MODE
      local idx = 1
      for i, m in ipairs(modes) do
        if m == current then
          idx = i
          break
        end
      end
      local next_mode = modes[(idx % #modes) + 1]

      -- Check if new mode requires stat and we should prefetch async
      if sort_comparators.mode_requires_stat(next_mode) then
        local data = data_module.load_data()
        local group = groups_module.find_group(data, group_path)
        if group and group.items and #group.items > 0 then
          local paths = sort_comparators.collect_paths(group.items)
          handle_async_sort(mp_state, paths, next_mode, constants.PANEL.ITEMS, function(state)
            state.right_sort_mode = next_mode
          end)
          return
        end
      end

      -- Sync path for non-stat modes
      utils.modify_ui_state(function(state)
        state.right_sort_mode = next_mode
      end)

      logger.info("Items sorted: %s", next_mode)
      mp_state:render_panel(constants.PANEL.ITEMS)
    end
  end
end

---Handle Sort Order toggle (asc/desc)
---@param mp_state MultiPanelState
function M.handle_sort_order(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  local order_name
  if focused == constants.PANEL.GROUPS then
    local ui_state = data_module.load_ui_state()
    local new_asc = not ui_state.left_sort_asc
    order_name = new_asc and "ascending" or "descending"

    utils.modify_ui_state(function(state)
      state.left_sort_asc = new_asc
    end)
    mp_state:render_panel(constants.PANEL.GROUPS)
  else
    local ui_state = data_module.load_ui_state()
    if utils.is_directory_view() then
      local new_asc = not ui_state.dir_sort_asc
      order_name = new_asc and "ascending" or "descending"
      utils.modify_ui_state(function(state)
        state.dir_sort_asc = new_asc
      end)
    else
      local new_asc = not ui_state.right_sort_asc
      order_name = new_asc and "ascending" or "descending"
      utils.modify_ui_state(function(state)
        state.right_sort_asc = new_asc
      end)
    end
    mp_state:render_panel(constants.PANEL.ITEMS)
  end

  logger.info("Sort order: %s", order_name)
end

-- ============================================================================
-- Reorder Handlers
-- ============================================================================

---Freeze current sort order as custom order for items
---@param mp_state MultiPanelState
---@param group_path string
---@return boolean success
local function freeze_items_order(mp_state, group_path)
  local sorted_items = mp_state._sorted_items
  if not sorted_items then return false end

  -- Update order fields to match current display order
  for i, item in ipairs(sorted_items) do
    item.order = i
  end

  -- Save to data file
  local data = data_module.load_data()
  local group = groups_module.find_group(data, group_path)
  if group then
    group.items = sorted_items
    data_module.save_data(data)
  end

  -- Switch to custom mode
  utils.modify_ui_state(function(state)
    state.right_sort_mode = constants.SORT_MODE.CUSTOM
  end)

  return true
end

---Check if reorder is valid based on direction and current position
---@param idx number Current index (1-based)
---@param total number Total items count
---@param direction "up"|"down"
---@return boolean can_reorder
local function can_reorder(idx, total, direction)
  if direction == "up" then
    return idx > 1
  else
    return idx > 0 and idx < total
  end
end

---Get cursor offset based on direction
---@param direction "up"|"down"
---@return number offset
local function get_cursor_offset(direction)
  return direction == "up" and -1 or 1
end

---Get the appropriate reorder function based on direction
---@param direction "up"|"down"
---@return function reorder_fn
local function get_reorder_fn(direction)
  return direction == "up" and sorting_module.reorder_up or sorting_module.reorder_down
end

---Handle reorder (shared implementation for move up/down)
---@param mp_state MultiPanelState
---@param direction "up"|"down"
local function handle_reorder(mp_state, direction)
  local focused = utils.get_focused_panel(mp_state)
  local ui_state = data_module.load_ui_state()

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  local reorder_fn = get_reorder_fn(direction)
  local cursor_offset = get_cursor_offset(direction)

  if focused == constants.PANEL.GROUPS then
    -- Ensure we're in custom sort mode
    if ui_state.left_sort_mode ~= constants.SORT_MODE.CUSTOM then
      sorting_module.freeze_groups_order()
      utils.modify_ui_state(function(state)
        state.left_sort_mode = constants.SORT_MODE.CUSTOM
      end)
      mp_state:render_panel(constants.PANEL.GROUPS)
      logger.info("Switched to custom sort mode")
    end

    local node = utils.get_node(element)
    if not node then return end

    -- Get parent path and find index in parent's children
    local parent_path = path_utils.get_parent_path(node.full_path)
    local data = data_module.load_data()
    local parent_list = parent_path == "" and data.groups or (groups_module.find_group(data, parent_path) or {}).children or {}

    -- Sort by order to get current display order
    local sorted = vim.tbl_values(parent_list)
    table.sort(sorted, function(a, b)
      return (a.order or 0) < (b.order or 0)
    end)

    -- Find current index
    local idx = 0
    for i, g in ipairs(sorted) do
      if g.name == node.name then
        idx = i
        break
      end
    end

    if can_reorder(idx, #sorted, direction) then
      local row = mp_state:get_cursor(constants.PANEL.GROUPS)
      reorder_fn(constants.ITEM_TYPE.GROUP, parent_path, idx)
      mp_state:render_panel(constants.PANEL.GROUPS)
      mp_state:set_cursor(constants.PANEL.GROUPS, row + cursor_offset)
    end
  else
    -- Check if we're in a dir_link view (can't reorder filesystem)
    if utils.is_directory_view() then
      logger.info("Cannot reorder directory contents")
      return
    end

    -- Ensure we're in custom sort mode
    if ui_state.right_sort_mode ~= constants.SORT_MODE.CUSTOM then
      local group_path = utils.get_group_path(element)
      if group_path and freeze_items_order(mp_state, group_path) then
        mp_state:render_panel(constants.PANEL.ITEMS)
        logger.info("Switched to custom sort mode")
      end
    end

    local group_path = utils.get_group_path(element)
    local index = utils.get_item_index(element)
    if not group_path or not index then return end

    local items_count = mp_state._sorted_items and #mp_state._sorted_items or 0

    if can_reorder(index, items_count, direction) then
      local row = mp_state:get_cursor(constants.PANEL.ITEMS)
      reorder_fn("item", group_path, index)
      mp_state:render_panel(constants.PANEL.ITEMS)
      mp_state:set_cursor(constants.PANEL.ITEMS, row + cursor_offset)
    end
  end
end

---Handle move up (reorder)
---@param mp_state MultiPanelState
function M.handle_move_up(mp_state)
  handle_reorder(mp_state, "up")
end

---Handle move down (reorder)
---@param mp_state MultiPanelState
function M.handle_move_down(mp_state)
  handle_reorder(mp_state, "down")
end

return M
