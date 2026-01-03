---@class FavdirUI
---Multi-panel UI for managing favorite directories
---@module favdir.ui

local M = {}

local state_module = require("favdir.state")
local icons = require("favdir.ui.icons")
local rendering = require("favdir.ui.rendering")
local handlers = require("favdir.ui.handlers")

---@type MultiPanelState?
local panel_state = nil

-- ============================================================================
-- Public API
-- ============================================================================

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

  local total_height = math.floor(vim.o.lines * config.window_height_ratio)
  local total_width = math.floor(vim.o.columns * config.window_width_ratio)

  panel_state = nvim_float.create_multi_panel({
    layout = {
      split = "horizontal",
      children = {
        {
          name = "groups",
          title = " Groups ",
          ratio = config.left_panel_width_ratio,
          on_render = rendering.render_left_panel,
        },
        {
          name = "items",
          title = " Items ",
          ratio = 1 - config.left_panel_width_ratio,
          on_render = rendering.render_right_panel,
        },
      },
    },
    total_width_ratio = config.window_width_ratio,
    total_height_ratio = config.window_height_ratio,
    footer = "? = Controls",
    initial_focus = "groups",
    controls = {
      {
        header = "Navigation",
        keys = {
          { key = "<CR>", desc = "Select group / Open item" },
          { key = "o", desc = "Expand/Collapse group" },
          { key = "<Tab>/<S-Tab>", desc = "Switch panel" },
          { key = "j/k", desc = "Move cursor" },
        },
      },
      {
        header = "Actions",
        keys = {
          { key = "a", desc = "Add group/item" },
          { key = "d", desc = "Delete" },
          { key = "r", desc = "Rename group" },
          { key = "m", desc = "Move item to group" },
          { key = "M", desc = "Move group to parent" },
        },
      },
      {
        header = "Sorting",
        keys = {
          { key = "s", desc = "Cycle sort mode" },
          { key = "<C-k>/<C-j>", desc = "Reorder up/down" },
        },
      },
      {
        header = "Open Options",
        keys = {
          { key = "<C-s>", desc = "Open in split" },
          { key = "|", desc = "Open in vsplit" },
          { key = "<C-t>", desc = "Open in tab" },
        },
      },
      {
        header = "Window",
        keys = {
          { key = "q/<Esc>", desc = "Close" },
        },
      },
    },
    on_close = function()
      panel_state = nil
    end,
  })

  if not panel_state then
    vim.notify("Failed to create favorites UI", vim.log.levels.ERROR)
    return
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

  -- Setup keymaps
  panel_state:set_keymaps({
    ["<CR>"] = function() handlers.handle_enter(panel_state) end,
    ["o"] = function() handlers.handle_toggle_expand(panel_state) end,
    ["<Tab>"] = function() panel_state:focus_next_panel() end,
    ["<S-Tab>"] = function() panel_state:focus_prev_panel() end,
    ["a"] = function() handlers.handle_add(panel_state) end,
    ["d"] = function() handlers.handle_delete(panel_state) end,
    ["r"] = function() handlers.handle_rename(panel_state) end,
    ["m"] = function() handlers.handle_move(panel_state) end,
    ["M"] = function() handlers.handle_move_group(panel_state) end,
    ["s"] = function() handlers.handle_sort(panel_state) end,
    ["<C-k>"] = function() handlers.handle_move_up(panel_state) end,
    ["<C-j>"] = function() handlers.handle_move_down(panel_state) end,
    ["<C-s>"] = function() handlers.handle_open_split(panel_state, "split") end,
    ["|"] = function() handlers.handle_open_split(panel_state, "vsplit") end,
    ["<C-t>"] = function() handlers.handle_open_split(panel_state, "tabnew") end,
    ["q"] = function()
      -- Save cursor positions before closing
      local row_l, col_l = panel_state:get_cursor("groups")
      local row_r, col_r = panel_state:get_cursor("items")
      local uis = state_module.load_ui_state()
      uis.left_cursor = { row = row_l, col = col_l }
      uis.right_cursor = { row = row_r, col = col_r }
      state_module.save_ui_state(uis)
      panel_state:close()
    end,
    ["<Esc>"] = function()
      local row_l, col_l = panel_state:get_cursor("groups")
      local row_r, col_r = panel_state:get_cursor("items")
      local uis = state_module.load_ui_state()
      uis.left_cursor = { row = row_l, col = col_l }
      uis.right_cursor = { row = row_r, col = col_r }
      state_module.save_ui_state(uis)
      panel_state:close()
    end,
  })
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
---@param config FavdirConfig
---@param item_path string Path to add
function M.pick_group_and_add_item(config, item_path)
  local groups = state_module.get_group_list()

  if #groups == 0 then
    vim.notify("No groups available. Create one first.", vim.log.levels.WARN)
    return
  end

  vim.ui.select(groups, { prompt = "Add to group:" }, function(group)
    if group then
      local ok, err = state_module.add_item(group, item_path)
      if not ok then
        vim.notify(err or "Failed to add item", vim.log.levels.ERROR)
      end
    end
  end)
end

return M
