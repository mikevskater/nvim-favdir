---@class FavdirUI
---Multi-panel UI for managing favorite directories
---@module favdir.ui

local M = {}

local state_module = require("nvim-favdir.state")
local icons = require("nvim-favdir.ui.icons")
local dialogs = require("nvim-favdir.ui.dialogs")
local panels = require("nvim-favdir.ui.rendering.panels")
local navigation = require("nvim-favdir.ui.handlers.navigation")
local editing = require("nvim-favdir.ui.handlers.editing")
local sorting = require("nvim-favdir.ui.handlers.sorting")
local opening = require("nvim-favdir.ui.handlers.opening")
local logger = require("nvim-favdir.logger")
local constants = require("nvim-favdir.constants")

---@type MultiPanelState?
local panel_state = nil

-- ============================================================================
-- Public API
-- ============================================================================

---Build controls list from keymaps config
---@param keys FavdirKeymaps
---@return table[]
local function build_controls(keys)
  return {
    {
      header = "Navigation",
      keys = {
        { key = keys.confirm, desc = "Select group / Open item" },
        { key = keys.expand_or_browse, desc = "Expand group / Browse folder" },
        { key = keys.go_up, desc = "Go up folder (dir_link)" },
        { key = keys.next_panel .. "/" .. keys.prev_panel, desc = "Switch panel" },
        { key = "j/k", desc = "Move cursor" },
      },
    },
    {
      header = "Actions",
      keys = {
        { key = keys.add, desc = "Add group/dir_link/item" },
        { key = keys.delete, desc = "Delete" },
        { key = keys.rename, desc = "Rename group" },
        { key = keys.move, desc = "Move item to group" },
        { key = keys.move_group, desc = "Move group to parent" },
      },
    },
    {
      header = "Sorting",
      keys = {
        { key = keys.sort, desc = "Cycle sort mode" },
        { key = keys.sort_order, desc = "Toggle asc/desc" },
        { key = keys.reorder_up .. "/" .. keys.reorder_down, desc = "Reorder up/down" },
      },
    },
    {
      header = "Open Options",
      keys = {
        { key = keys.open_split, desc = "Open in split" },
        { key = keys.open_vsplit, desc = "Open in vsplit" },
        { key = keys.open_tab, desc = "Open in tab" },
      },
    },
    {
      header = "Window",
      keys = {
        { key = keys.close .. "/" .. keys.close_alt, desc = "Close" },
      },
    },
  }
end

---Build keymaps table from config
---@param keys FavdirKeymaps
---@param ps MultiPanelState
---@return table<string, function>
local function build_keymaps(keys, ps)
  local close_handler = function()
    local row_l, col_l = ps:get_cursor("groups")
    local row_r, col_r = ps:get_cursor("items")
    local uis = state_module.load_ui_state()
    uis.left_cursor = { row = row_l, col = col_l }
    uis.right_cursor = { row = row_r, col = col_r }
    state_module.save_ui_state(uis)
    ps:close()
  end

  return {
    [keys.confirm] = function() navigation.handle_enter(ps) end,
    [keys.expand_or_browse] = function()
      if ps.focused_panel == "groups" then
        navigation.handle_toggle_expand(ps)
      else
        navigation.handle_browse_folder(ps)
      end
    end,
    [keys.go_up] = function() navigation.handle_go_up(ps) end,
    [keys.next_panel] = function() ps:focus_next_panel() end,
    [keys.prev_panel] = function() ps:focus_prev_panel() end,
    [keys.add] = function() editing.handle_add(ps) end,
    [keys.delete] = function() editing.handle_delete(ps) end,
    [keys.rename] = function() editing.handle_rename(ps) end,
    [keys.move] = function() editing.handle_move(ps) end,
    [keys.move_group] = function() editing.handle_move_group(ps) end,
    [keys.sort] = function() sorting.handle_sort(ps) end,
    [keys.sort_order] = function() sorting.handle_sort_order(ps) end,
    [keys.reorder_up] = function() sorting.handle_move_up(ps) end,
    [keys.reorder_down] = function() sorting.handle_move_down(ps) end,
    [keys.open_split] = function() opening.handle_open_split(ps, "split") end,
    [keys.open_vsplit] = function() opening.handle_open_split(ps, "vsplit") end,
    [keys.open_tab] = function() opening.handle_open_split(ps, "tabnew") end,
    [keys.close] = close_handler,
    [keys.close_alt] = close_handler,
  }
end

---Show the favorites UI
---@param config FavdirConfig
function M.show(config)
  -- Select icon set based on config (Nerd Font or ASCII)
  icons.select_icon_set(config.use_nerd_font == true)

  if panel_state and panel_state:is_valid() then
    -- Already open, focus it
    panel_state:focus_panel(panel_state.focused_panel)
    return
  end

  local nvim_float = require("nvim-float")
  local keys = config.keymaps

  panel_state = nvim_float.create_multi_panel({
    layout = {
      split = "horizontal",
      children = {
        {
          name = "groups",
          title = " Groups ",
          ratio = config.left_panel_width_ratio,
          on_render = panels.render_left_panel,
        },
        {
          name = "items",
          title = " Items ",
          ratio = 1 - config.left_panel_width_ratio,
          on_render = panels.render_right_panel,
        },
      },
    },
    total_width_ratio = config.window_width_ratio,
    total_height_ratio = config.window_height_ratio,
    footer = "? = Controls",
    initial_focus = "groups",
    controls = build_controls(keys),
    on_close = function()
      panel_state = nil
    end,
  })

  if not panel_state then
    logger.error("Failed to create favorites UI")
    return
  end

  logger.debug("Created multi-panel UI")

  -- Ensure a group is selected if none is (auto-select first group)
  local ui_state = state_module.load_ui_state()
  if not ui_state.last_selected_group and not ui_state.last_selected_dir_link then
    -- No selection - try to auto-select first available group
    local data = state_module.load_data()
    if data.groups and #data.groups > 0 then
      ui_state.last_selected_type = constants.SELECTION_TYPE.GROUP
      ui_state.last_selected_group = data.groups[1].name
      state_module.save_ui_state(ui_state)
    end
  end

  -- Render initial content
  panel_state:render_all()

  -- Enable element tracking for both panels
  -- Note: ContentBuilder association happens in render functions
  vim.schedule(function()
    if panel_state and panel_state:is_valid() then
      panel_state:enable_element_tracking("groups")
      panel_state:enable_element_tracking("items")
    end
  end)

  -- Restore cursor positions
  local ui_state = state_module.load_ui_state()
  if ui_state.left_cursor then
    panel_state:set_cursor("groups", ui_state.left_cursor.row, ui_state.left_cursor.col)
  end
  if ui_state.right_cursor then
    panel_state:set_cursor("items", ui_state.right_cursor.row, ui_state.right_cursor.col)
  end

  -- Setup keymaps from config
  panel_state:set_keymaps(build_keymaps(keys, panel_state))
end

---Toggle the UI
---@param config FavdirConfig
function M.toggle(config)
  if panel_state and panel_state:is_valid() then
    panel_state:close()
  else
    M.show(config)
  end
end

---Pick a group and add an item to it
---@param item_path string Path to add
function M.pick_group_and_add_item(item_path)
  local groups = state_module.get_group_list()

  if #groups == 0 then
    logger.warn("No groups available. Create one first.")
    return
  end

  dialogs.select("Add to group", groups, function(_, group)
    if group then
      local ok, err = state_module.add_item(group, item_path)
      if not ok then
        logger.error(err or "Failed to add item")
      end
    end
  end)
end

return M
