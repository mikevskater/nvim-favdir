---@module nvim-favdir.health
---Checkhealth integration for nvim-favdir

local M = {}

function M.check()
  vim.health.start("nvim-favdir")

  -- Check Neovim version
  if vim.fn.has("nvim-0.8") == 1 then
    vim.health.ok("Neovim version: " .. tostring(vim.version()))
  else
    vim.health.error("Neovim >= 0.8.0 required", { "Update Neovim to 0.8.0 or later" })
  end

  -- Check nvim-float dependency
  local float_ok, _ = pcall(require, "nvim-float")
  if float_ok then
    vim.health.ok("nvim-float: found")
  else
    vim.health.error("nvim-float: not found", {
      "Install nvim-float: https://github.com/mikevskater/nvim-float",
    })
  end

  -- Check optional: nvim-web-devicons
  local devicons_ok, _ = pcall(require, "nvim-web-devicons")
  if devicons_ok then
    vim.health.ok("nvim-web-devicons: found (enhanced file icons)")
  else
    vim.health.info("nvim-web-devicons: not found (optional, for enhanced file icons)")
  end

  -- Check optional: mini.icons
  local mini_ok, _ = pcall(require, "mini.icons")
  if mini_ok then
    vim.health.ok("mini.icons: found (alternative icon provider)")
  else
    vim.health.info("mini.icons: not found (optional)")
  end

  -- Check data file access
  local data_path = vim.fn.stdpath("data") .. "/favdirs.json"
  local data_dir = vim.fn.fnamemodify(data_path, ":h")
  if vim.fn.isdirectory(data_dir) == 1 then
    vim.health.ok("Data directory exists: " .. data_dir)
  else
    vim.health.warn("Data directory does not exist: " .. data_dir, {
      "It will be created automatically on first use",
    })
  end

  if vim.fn.filereadable(data_path) == 1 then
    vim.health.ok("Data file exists: " .. data_path)
  else
    vim.health.info("Data file not yet created: " .. data_path)
  end

  -- Check Nerd Font availability
  if vim.g.have_nerd_font == true then
    vim.health.ok("Nerd Font: vim.g.have_nerd_font = true")
  elseif vim.g.have_nerd_font == false then
    vim.health.info("Nerd Font: vim.g.have_nerd_font = false (using ASCII icons)")
  elseif devicons_ok or mini_ok then
    vim.health.ok("Nerd Font: likely available (icon plugin detected)")
  else
    vim.health.info("Nerd Font: unknown (set vim.g.have_nerd_font to confirm)")
  end
end

return M
