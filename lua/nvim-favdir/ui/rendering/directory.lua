---@module favdir.ui.rendering.directory
---Directory link contents rendering for favdir

local M = {}

local data_module = require("nvim-favdir.state.data")
local icons = require("nvim-favdir.ui.icons")
local sort_comparators = require("nvim-favdir.state.sort_comparators")
local constants = require("nvim-favdir.constants")
local dir_cache = require("nvim-favdir.state.dir_cache")

-- Forward declaration for interaction handler
local on_item_interact

---Set the item interaction handler (called by panels module to avoid circular deps)
---@param handler fun(element: TrackedElement, mp_state: MultiPanelState)
function M.set_item_interact_handler(handler)
  on_item_interact = handler
end

-- ============================================================================
-- Async Directory Reading
-- ============================================================================

---Read directory contents asynchronously using vim.uv.fs_scandir
---@param dir_path string
---@param callback fun(entries: string[]?, err: string?)
local function readdir_async(dir_path, callback)
  vim.uv.fs_scandir(dir_path, function(err, handle)
    if err then
      vim.schedule(function() callback(nil, err) end)
      return
    end
    local entries = {}
    while true do
      local name = vim.uv.fs_scandir_next(handle)
      if not name then break end
      table.insert(entries, name)
    end
    vim.schedule(function() callback(entries) end)
  end)
end

-- ============================================================================
-- Entry Rendering Helper
-- ============================================================================

---Render pre-read directory entries into a ContentBuilder
---@param mp_state MultiPanelState
---@param cb any ContentBuilder instance
---@param base_path string Base directory path
---@param current_path string Current browsing path
---@param raw_entries string[] Raw readdir results
---@return string[] lines
---@return table[] highlights
local function render_entries(mp_state, cb, base_path, current_path, raw_entries)
  -- Check if we're in a subfolder (show "../" entry)
  local is_in_subfolder = vim.fn.fnamemodify(current_path, ':p') ~= vim.fn.fnamemodify(base_path, ':p')

  -- In browse mode (from group directory item), always show "../" as exit indicator
  local ui_state = data_module.load_ui_state()
  local show_parent_entry = is_in_subfolder or ui_state.is_browsing_directory

  -- Build items list with type info
  local items = {}

  -- Add "../" entry if in subfolder OR in browse mode (as exit indicator)
  if show_parent_entry then
    table.insert(items, {
      name = "..",
      path = vim.fn.fnamemodify(current_path, ':h'),
      type = constants.ITEM_TYPE.PARENT,
    })
  end

  -- Filter hidden files unless show_hidden_files is enabled
  local show_hidden = ui_state.show_hidden_files ~= false
  for _, entry in ipairs(raw_entries) do
    if not show_hidden and entry:sub(1, 1) == "." then
      goto continue
    end
    local full_path = vim.fs.joinpath(current_path, entry)
    local is_dir = vim.fn.isdirectory(full_path) == 1
    table.insert(items, {
      name = entry,
      path = full_path,
      type = is_dir and constants.ITEM_TYPE.DIR or constants.ITEM_TYPE.FILE,
    })
    ::continue::
  end

  -- Sort based on dir_sort_mode (parent ".." always first)
  local sort_mode = ui_state.dir_sort_mode or "type"
  local sort_asc = ui_state.dir_sort_asc ~= false -- default to true
  table.sort(items, sort_comparators.directory_comparator(sort_mode, sort_asc))

  -- Store for operations
  mp_state._sorted_items = items
  mp_state._is_dir_link_view = true

  if #raw_entries == 0 and not show_parent_entry then
    cb:muted("Directory is empty")
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  for _, item in ipairs(items) do
    local icon, color
    if item.type == constants.ITEM_TYPE.PARENT then
      icon = icons.get_base_icon("collapsed")
      color = nil
    elseif item.type == constants.ITEM_TYPE.DIR then
      icon = icons.get_base_icon("directory")
      color = icons.get_directory_color()
    else
      icon, color = icons.get_file_icon(item.path)
    end

    local icon_hl = color and icons.get_icon_hl(color) or nil

    -- Build line with element tracking
    cb:spans({
      {
        text = icon .. " ",
        hl_group = icon_hl,
        track = {
          name = item.path,
          type = "action",
          row_based = true,
          hover_style = "emphasis",
          data = {
            item = item,
            panel = constants.PANEL.ITEMS,
            is_dir_link_view = true,
            base_path = base_path,
          },
          on_interact = function(element)
            if on_item_interact then
              on_item_interact(element, mp_state)
            end
          end,
        },
      },
      { text = item.name, style = (item.type == constants.ITEM_TYPE.DIR or item.type == constants.ITEM_TYPE.PARENT) and "strong" or nil },
    })
  end

  mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)

  return cb:build_lines(), cb:build_highlights()
end

-- ============================================================================
-- Directory Link Contents Rendering
-- ============================================================================

---Render filesystem contents for a directory link
---@param mp_state MultiPanelState
---@param cb any ContentBuilder instance
---@param base_path string Base directory path (the dir_link's original path)
---@param current_path string Current browsing path (may be a subfolder)
---@return string[] lines
---@return table[] highlights
function M.render_dir_link_contents(mp_state, cb, base_path, current_path)
  -- Validate directory exists
  if vim.fn.isdirectory(current_path) ~= 1 then
    cb:muted("Directory not found:")
    cb:muted(current_path)
    mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)
    return cb:build_lines(), cb:build_highlights()
  end

  -- Store base path for navigation validation
  mp_state._dir_link_base_path = base_path
  mp_state._dir_link_current_path = current_path

  -- Fast path: entries are cached
  local cached_entries = dir_cache.get(current_path)
  if cached_entries then
    return render_entries(mp_state, cb, base_path, current_path, cached_entries)
  end

  -- Slow path: show loading placeholder and read asynchronously
  mp_state._is_dir_link_view = true
  mp_state._sorted_items = {}
  cb:muted("Loading...")
  mp_state:set_panel_content_builder(constants.PANEL.ITEMS, cb)

  readdir_async(current_path, function(entries, err)
    if not mp_state:is_valid() then return end

    if not entries then
      -- Async read failed — fall back to sync attempt
      local ok, sync_entries = pcall(vim.fn.readdir, current_path)
      if ok and sync_entries then
        entries = sync_entries
      else
        -- Cache empty result to prevent re-render loop
        dir_cache.set(current_path, {})
        mp_state:render_panel(constants.PANEL.ITEMS)
        return
      end
    end

    -- Cache the results and trigger a re-render (will hit the fast path)
    dir_cache.set(current_path, entries)
    mp_state:render_panel(constants.PANEL.ITEMS)
  end)

  return cb:build_lines(), cb:build_highlights()
end

return M
