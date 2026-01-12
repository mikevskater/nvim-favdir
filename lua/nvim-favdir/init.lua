---@class FavdirModule
---Favorite directories plugin for Neovim
---Two-panel UI for managing groups and favorite directories/files
---@module favdir

local M = {}

M.version = "1.3.1"

local state = require("nvim-favdir.state")
local ui = require("nvim-favdir.ui")
local logger = require("nvim-favdir.logger")

---@class FavdirKeymaps
---@field open string|false Global keymap to open UI (false to disable)
---@field confirm string Select group / Open item
---@field expand_or_browse string Expand group / Browse folder
---@field go_up string Go up folder level
---@field next_panel string Switch to next panel
---@field prev_panel string Switch to previous panel
---@field add string Add group/dir_link/item
---@field delete string Delete
---@field rename string Rename group
---@field move string Move item to group
---@field move_group string Move group to parent
---@field sort string Cycle sort mode
---@field sort_order string Toggle sort order (asc/desc)
---@field reorder_up string Reorder up
---@field reorder_down string Reorder down
---@field open_split string Open in split
---@field open_vsplit string Open in vsplit
---@field open_tab string Open in tab
---@field close string Close UI
---@field close_alt string Alternative close key

---@class FavdirConfig
---@field data_file string Path to data file
---@field ui_state_file string Path to UI state file
---@field window_height_ratio number Height ratio (0-1)
---@field window_width_ratio number Width ratio (0-1)
---@field left_panel_width_ratio number Left panel width ratio (0-1)
---@field default_groups string[] Default groups on first run
---@field protected_groups string[] Groups that cannot be deleted/moved
---@field use_nerd_font boolean Use Nerd Font icons
---@field debug_mode boolean Enable debug logging (default: false)
---@field log_to_file boolean Write logs to file (default: false)
---@field keymaps FavdirKeymaps Keymaps configuration

---@type FavdirConfig
M.config = {
  data_file = vim.fn.stdpath('data') .. '/favdirs.json',
  ui_state_file = vim.fn.stdpath('data') .. '/favdirs_ui_state.json',
  window_height_ratio = 0.7,
  window_width_ratio = 0.8,
  left_panel_width_ratio = 0.35,
  default_groups = {},
  protected_groups = {},
  use_nerd_font = true,
  debug_mode = false,
  log_to_file = false,
  keymaps = {
    -- Global
    open = "<leader>ofd",
    -- Navigation
    confirm = "<CR>",
    expand_or_browse = "o",
    go_up = "<BS>",
    next_panel = "<Tab>",
    prev_panel = "<S-Tab>",
    -- Actions
    add = "a",
    delete = "d",
    rename = "r",
    move = "m",
    move_group = "M",
    -- Sorting
    sort = "s",
    sort_order = "S",
    reorder_up = "<C-k>",
    reorder_down = "<C-j>",
    -- Open options
    open_split = "<C-s>",
    open_vsplit = "|",
    open_tab = "<C-t>",
    -- Window
    close = "q",
    close_alt = "<Esc>",
  },
}

local initialized = false
local keymaps_set = false

---Setup global keymaps based on config
local function setup_keymaps()
  if keymaps_set then return end

  local keymaps = M.config.keymaps
  if keymaps.open and keymaps.open ~= false then
    vim.keymap.set("n", keymaps.open, "<cmd>FavdirOpen<cr>", {
      desc = "Open favorite directories",
      silent = true,
    })
  end

  keymaps_set = true
end

---Detect if Nerd Fonts are likely available
---@return boolean
local function detect_nerd_font()
  -- User explicitly set vim.g.have_nerd_font
  if vim.g.have_nerd_font == true then return true end
  if vim.g.have_nerd_font == false then return false end

  -- Check if nvim-web-devicons is available (implies Nerd Font usage)
  if pcall(require, "nvim-web-devicons") then return true end

  -- Check if mini.icons is available
  if pcall(require, "mini.icons") then return true end

  -- Check for common Nerd Font terminal environment hints
  local term = vim.env.TERM_PROGRAM or ""
  local nerd_font_terminals = { "WezTerm", "Alacritty", "kitty", "iTerm.app" }
  for _, t in ipairs(nerd_font_terminals) do
    if term:find(t, 1, true) then return true end
  end

  return false
end

---Initialize the plugin
local function init()
  if initialized then return end

  -- Initialize logger first
  logger.init({
    debug_mode = M.config.debug_mode,
    log_to_file = M.config.log_to_file,
    notify_prefix = "favdir",
  })

  logger.debug("Initializing favdir v%s", M.version)

  -- Auto-detect Nerd Font if using default
  if M.config.use_nerd_font == true and not vim.g.have_nerd_font then
    M.config.use_nerd_font = detect_nerd_font()
    logger.debug("Nerd Font auto-detected: %s", M.config.use_nerd_font)
  end


  -- Initialize state with config
  state.init(M.config)

  logger.debug("Initialization complete")
  initialized = true
end

---Setup the plugin with user configuration
---@param opts FavdirConfig? User configuration options
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  initialized = false
  keymaps_set = false
  init()
  setup_keymaps()
end

---Show the favorites UI
function M.show()
  init()
  ui.show(M.config)
end

---Toggle the favorites UI
function M.toggle()
  init()
  ui.toggle(M.config)
end

---Show the favorites UI in sandbox mode (clean state, no persistence)
---Useful for demos, testing, and VHS recordings
---@param initial_data FavdirData? Optional initial data
function M.show_sandbox(initial_data)
  init()
  state.enable_sandbox(initial_data)
  ui.show(M.config)
end

---Close sandbox mode and return to normal operation
function M.close_sandbox()
  state.disable_sandbox()
end

---Check if currently in sandbox mode
---@return boolean
function M.is_sandbox()
  return state.is_sandbox()
end

---Add the current working directory to favorites
---@param group_path string? Optional group path (prompts if not provided)
function M.add_cwd(group_path)
  init()
  local cwd = vim.fn.getcwd()
  if group_path then
    state.add_item(group_path, cwd)
  else
    ui.pick_group_and_add_item(cwd)
  end
end

---Add the current buffer's file to favorites
---@param group_path string? Optional group path (prompts if not provided)
function M.add_file(group_path)
  init()
  local file = vim.fn.expand('%:p')
  if file == "" then
    logger.warn("No file in current buffer")
    return
  end
  if group_path then
    state.add_item(group_path, file)
  else
    ui.pick_group_and_add_item(file)
  end
end

---Get all data (for external access)
---@return FavdirData
function M.get_data()
  init()
  return state.load_data()
end

---Get all groups as flat list
---@return string[]
function M.get_groups()
  init()
  return state.get_group_list()
end

return M
