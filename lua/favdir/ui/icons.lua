---@module favdir.ui.icons
---Icon definitions and lookup functions for favdir

local M = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

---Convert codepoint to UTF-8 character
---@param codepoint number
---@return string
local function nf(codepoint)
  return vim.fn.nr2char(codepoint)
end

-- ============================================================================
-- Module State
-- ============================================================================

-- Whether to use Nerd Font icons (set by select_icon_set)
local use_nerd_font = true

-- Cache for dynamically created highlight groups
local hl_cache = {}

-- ============================================================================
-- Type Definitions
-- ============================================================================

---@class IconDef
---@field nerd string Nerd Font icon
---@field ascii string ASCII fallback
---@field color string? Hex color for the icon

---@class BaseIconDef
---@field nerd string Nerd Font icon
---@field ascii string ASCII fallback

-- ============================================================================
-- Icon Definitions
-- ============================================================================

-- Base UI icons (expand/collapse, directory, file)
---@type table<string, BaseIconDef>
local base_icons = {
  expanded   = { nerd = "▼",           ascii = "[-]" },
  collapsed  = { nerd = "▶",           ascii = "[+]" },
  leaf       = { nerd = "•",           ascii = " - " },  -- Bullet for leaf nodes
  directory  = { nerd = nf(0xF07B),    ascii = "[D]" },  -- nf-fa-folder
  file       = { nerd = nf(0xF15B),    ascii = "[F]" },  -- nf-fa-file
}

-- File extension icons with colors (from nvim-web-devicons)
---@type table<string, IconDef>
local file_icons = {
  -- Lua
  lua      = { nerd = nf(0xE620), ascii = "lua", color = "#51A0CF" },

  -- Python
  py       = { nerd = nf(0xE73C), ascii = "py",  color = "#FFDC51" },
  python   = { nerd = nf(0xE73C), ascii = "py",  color = "#FFDC51" },
  pyw      = { nerd = nf(0xE73C), ascii = "py",  color = "#FFDC51" },
  pyx      = { nerd = nf(0xE73C), ascii = "py",  color = "#FFDC51" },

  -- JavaScript/TypeScript
  js       = { nerd = nf(0xE74E), ascii = "js",  color = "#F1E05A" },
  mjs      = { nerd = nf(0xE74E), ascii = "js",  color = "#F1E05A" },
  cjs      = { nerd = nf(0xE74E), ascii = "js",  color = "#F1E05A" },
  ts       = { nerd = nf(0xE628), ascii = "ts",  color = "#3178C6" },
  mts      = { nerd = nf(0xE628), ascii = "ts",  color = "#3178C6" },
  tsx      = { nerd = nf(0xE7BA), ascii = "tsx", color = "#20C2E3" },
  jsx      = { nerd = nf(0xE7BA), ascii = "jsx", color = "#20C2E3" },

  -- Web
  json     = { nerd = nf(0xE60B), ascii = "{}", color = "#CBCB41" },
  jsonc    = { nerd = nf(0xE60B), ascii = "{}", color = "#CBCB41" },
  html     = { nerd = nf(0xE736), ascii = "<>", color = "#E44D26" },
  htm      = { nerd = nf(0xE736), ascii = "<>", color = "#E44D26" },
  css      = { nerd = nf(0xE749), ascii = "#",  color = "#563D7C" },
  scss     = { nerd = nf(0xE749), ascii = "#",  color = "#CF649A" },
  sass     = { nerd = nf(0xE749), ascii = "#",  color = "#CF649A" },
  less     = { nerd = nf(0xE749), ascii = "#",  color = "#1D365D" },
  vue      = { nerd = nf(0xE6A0), ascii = "vue", color = "#42B883" },
  svelte   = { nerd = nf(0xE697), ascii = "sve", color = "#FF3E00" },

  -- Markdown/Docs
  md       = { nerd = nf(0xE609), ascii = "md",  color = "#DDDDDD" },
  markdown = { nerd = nf(0xE609), ascii = "md",  color = "#DDDDDD" },
  mdx      = { nerd = nf(0xE609), ascii = "mdx", color = "#DDDDDD" },
  txt      = { nerd = nf(0xF15C), ascii = "txt", color = "#89E051" },
  rst      = { nerd = nf(0xF15C), ascii = "rst", color = "#89E051" },

  -- Config/Data
  yaml     = { nerd = nf(0xE6A8), ascii = "yml", color = "#CB171E" },
  yml      = { nerd = nf(0xE6A8), ascii = "yml", color = "#CB171E" },
  toml     = { nerd = nf(0xE615), ascii = "cfg", color = "#9C4121" },
  xml      = { nerd = nf(0xE619), ascii = "xml", color = "#E37933" },
  ini      = { nerd = nf(0xE615), ascii = "ini", color = "#6D8086" },
  conf     = { nerd = nf(0xE615), ascii = "cfg", color = "#6D8086" },
  config   = { nerd = nf(0xE615), ascii = "cfg", color = "#6D8086" },
  env      = { nerd = nf(0xF462), ascii = "env", color = "#ECD53F" },

  -- Shell
  sh       = { nerd = nf(0xF489), ascii = "$",   color = "#4EAA25" },
  bash     = { nerd = nf(0xF489), ascii = "$",   color = "#4EAA25" },
  zsh      = { nerd = nf(0xF489), ascii = "$",   color = "#4EAA25" },
  fish     = { nerd = nf(0xF489), ascii = "$",   color = "#4EAA25" },
  ps1      = { nerd = nf(0xF489), ascii = ">_",  color = "#012456" },
  bat      = { nerd = nf(0xF489), ascii = ">_",  color = "#C1F12E" },
  cmd      = { nerd = nf(0xF489), ascii = ">_",  color = "#C1F12E" },

  -- C/C++
  c        = { nerd = nf(0xE61E), ascii = "C",   color = "#599EFF" },
  h        = { nerd = nf(0xE61E), ascii = "H",   color = "#A074C4" },
  cpp      = { nerd = nf(0xE61D), ascii = "C+",  color = "#F34B7D" },
  cc       = { nerd = nf(0xE61D), ascii = "C+",  color = "#F34B7D" },
  cxx      = { nerd = nf(0xE61D), ascii = "C+",  color = "#F34B7D" },
  hpp      = { nerd = nf(0xE61D), ascii = "H+",  color = "#A074C4" },
  hxx      = { nerd = nf(0xE61D), ascii = "H+",  color = "#A074C4" },

  -- Rust/Go
  rs       = { nerd = nf(0xE7A8), ascii = "rs",  color = "#DEA584" },
  go       = { nerd = nf(0xE626), ascii = "go",  color = "#00ADD8" },
  mod      = { nerd = nf(0xE626), ascii = "mod", color = "#00ADD8" },
  sum      = { nerd = nf(0xE626), ascii = "sum", color = "#00ADD8" },

  -- JVM
  java     = { nerd = nf(0xE738), ascii = "jav", color = "#CC3E44" },
  jar      = { nerd = nf(0xE738), ascii = "jar", color = "#CC3E44" },
  kt       = { nerd = nf(0xE634), ascii = "kt",  color = "#7F52FF" },
  kts      = { nerd = nf(0xE634), ascii = "kts", color = "#7F52FF" },
  scala    = { nerd = nf(0xE737), ascii = "sca", color = "#CC3E44" },
  groovy   = { nerd = nf(0xE775), ascii = "gvy", color = "#4298B8" },
  gradle   = { nerd = nf(0xE660), ascii = "grd", color = "#02303A" },

  -- Ruby/PHP
  rb       = { nerd = nf(0xE739), ascii = "rb",  color = "#CC342D" },
  ruby     = { nerd = nf(0xE739), ascii = "rb",  color = "#CC342D" },
  erb      = { nerd = nf(0xE739), ascii = "erb", color = "#CC342D" },
  php      = { nerd = nf(0xE73D), ascii = "php", color = "#777BB3" },

  -- .NET
  cs       = { nerd = nf(0xF81A), ascii = "C#",  color = "#68217A" },
  fs       = { nerd = nf(0xE7A7), ascii = "F#",  color = "#378BBA" },
  vb       = { nerd = nf(0xF81A), ascii = "vb",  color = "#945DB7" },
  sln      = { nerd = nf(0xE70C), ascii = "sln", color = "#854CC7" },

  -- Database
  sql      = { nerd = nf(0xE706), ascii = "sql", color = "#67c1f5" },
  db       = { nerd = nf(0xE706), ascii = "db",  color = "#e0ffb6" },
  sqlite   = { nerd = nf(0xE706), ascii = "sql", color = "#0F80CC" },

  -- Vim/Editor
  vim      = { nerd = nf(0xE62B), ascii = "vim", color = "#019833" },
  nvim     = { nerd = nf(0xE62B), ascii = "vim", color = "#019833" },

  -- Git
  git           = { nerd = nf(0xE702), ascii = "git", color = "#F14C28" },
  gitignore     = { nerd = nf(0xE702), ascii = "git", color = "#F14C28" },
  gitattributes = { nerd = nf(0xE702), ascii = "git", color = "#F14C28" },
  gitmodules    = { nerd = nf(0xE702), ascii = "git", color = "#F14C28" },

  -- Docker
  dockerfile    = { nerd = nf(0xE7B0), ascii = "doc", color = "#2496ED" },
  docker        = { nerd = nf(0xE7B0), ascii = "doc", color = "#2496ED" },
  dockerignore  = { nerd = nf(0xE7B0), ascii = "doc", color = "#2496ED" },

  -- Build/Config files
  makefile = { nerd = nf(0xE779), ascii = "mk",  color = "#6D8086" },
  cmake    = { nerd = nf(0xE615), ascii = "cmk", color = "#6D8086" },
  rake     = { nerd = nf(0xE739), ascii = "rak", color = "#CC342D" },
  just     = { nerd = nf(0xE615), ascii = "jst", color = "#6D8086" },

  -- Images
  png      = { nerd = nf(0xF1C5), ascii = "img", color = "#A074C4" },
  jpg      = { nerd = nf(0xF1C5), ascii = "img", color = "#A074C4" },
  jpeg     = { nerd = nf(0xF1C5), ascii = "img", color = "#A074C4" },
  gif      = { nerd = nf(0xF1C5), ascii = "gif", color = "#A074C4" },
  svg      = { nerd = nf(0xF1C5), ascii = "svg", color = "#FFB13B" },
  ico      = { nerd = nf(0xF1C5), ascii = "ico", color = "#CBCB41" },
  webp     = { nerd = nf(0xF1C5), ascii = "img", color = "#A074C4" },
  bmp      = { nerd = nf(0xF1C5), ascii = "bmp", color = "#A074C4" },

  -- Archives
  zip      = { nerd = nf(0xF1C6), ascii = "zip", color = "#ECA517" },
  tar      = { nerd = nf(0xF1C6), ascii = "tar", color = "#ECA517" },
  gz       = { nerd = nf(0xF1C6), ascii = "gz",  color = "#ECA517" },
  rar      = { nerd = nf(0xF1C6), ascii = "rar", color = "#ECA517" },
  ["7z"]   = { nerd = nf(0xF1C6), ascii = "7z",  color = "#ECA517" },

  -- Lock files
  lock     = { nerd = nf(0xF023), ascii = "lck", color = "#BBBBBB" },

  -- Misc
  log      = { nerd = nf(0xF18D), ascii = "log", color = "#DDDDDD" },
  pdf      = { nerd = nf(0xF1C1), ascii = "pdf", color = "#B30B00" },
  license  = { nerd = nf(0xF0219), ascii = "lic", color = "#CBCB41" },
}

-- Default colors for base icons
local base_colors = {
  directory = "#E8AB53",  -- Folder yellow
  file = "#6D8086",       -- Default file gray
}

-- ============================================================================
-- Public API
-- ============================================================================

---Get a base icon (expanded, collapsed, directory, file)
---@param icon_name string
---@return string icon
function M.get_base_icon(icon_name)
  local def = base_icons[icon_name]
  if not def then
    return "?"
  end
  return use_nerd_font and def.nerd or def.ascii
end

---Get icon and color for a file extension
---@param path string
---@return string icon, string? color
function M.get_file_icon(path)
  local name = vim.fn.fnamemodify(path, ':t'):lower()
  local ext = vim.fn.fnamemodify(path, ':e'):lower()

  -- Check full filename first (for dotfiles like .gitignore)
  local def = file_icons[name]
  if def then
    local icon = use_nerd_font and def.nerd or def.ascii
    return icon, def.color
  end

  -- Check extension
  def = file_icons[ext]
  if def then
    local icon = use_nerd_font and def.nerd or def.ascii
    return icon, def.color
  end

  -- Default file icon
  local base = base_icons.file
  return use_nerd_font and base.nerd or base.ascii, base_colors.file
end

---Select icon set based on config
---@param use_nerd boolean
function M.select_icon_set(use_nerd)
  use_nerd_font = use_nerd
end

---Get or create a highlight group for an icon color
---@param color string? Hex color like "#51A0CF"
---@return string? hl_group_name
function M.get_icon_hl(color)
  if not color then
    return nil
  end

  -- Create a safe highlight group name from the color
  local hl_name = "FavdirIcon_" .. color:gsub("#", "")

  -- Cache and create the highlight group if it doesn't exist
  if not hl_cache[hl_name] then
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
    hl_cache[hl_name] = true
  end

  return hl_name
end

---Get the directory icon color
---@return string
function M.get_directory_color()
  return base_colors.directory
end

---Get the default file icon color
---@return string
function M.get_file_color()
  return base_colors.file
end

return M
