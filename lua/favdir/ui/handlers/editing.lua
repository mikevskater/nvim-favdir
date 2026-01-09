---@module favdir.ui.handlers.editing
---Editing handlers for favdir (add, delete, rename, move)

local M = {}

local state_module = require("favdir.state")
local dialogs = require("favdir.ui.dialogs")
local utils = require("favdir.ui.handlers.utils")
local logger = require("favdir.logger")
local path_utils = require("favdir.path_utils")

-- ============================================================================
-- Add Handlers
-- ============================================================================

---Handle Add key
---@param mp_state MultiPanelState
function M.handle_add(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused == "groups" then
    local element = mp_state:get_element_at_cursor()
    local node = element and element.data and element.data.node

    -- If cursor is on a dir_link, we can't add children to it
    if node and node.is_dir_link then
      logger.warn("Cannot add children to a directory link")
      return
    end

    local parent_path = node and node.full_path or ""

    -- Show options: Add group or Add directory link
    local options = { "Add group", "Add directory link" }
    dialogs.select("Add to " .. (parent_path ~= "" and parent_path or "root"), options, function(idx, choice)
      if not choice then return end

      if choice == "Add group" then
        -- Add child group
        dialogs.input("Add Group", "Group Name:", "", function(name)
          local ok, err = state_module.add_group(parent_path, name)
          if ok then
            -- Expand parent to show new child
            if parent_path ~= "" then
              local ui_state = state_module.load_ui_state()
              if not state_module.is_expanded(ui_state, parent_path) then
                state_module.toggle_expanded(parent_path)
              end
            end
            vim.schedule(function()
              if mp_state and mp_state:is_valid() then
                mp_state:render_panel("groups")
              end
            end)
          else
            logger.error(err or "Failed to add group")
          end
        end)
      else
        -- Add directory link
        if parent_path == "" then
          logger.warn("Directory links must be added inside a group")
          return
        end

        dialogs.input("Add Directory Link", "Directory Path:", vim.fn.getcwd(), function(dir_path)
          if not dir_path or dir_path == "" then return end

          -- Default name to directory basename
          local default_name = vim.fn.fnamemodify(dir_path, ':t')
          dialogs.input("Add Directory Link", "Display Name:", default_name, function(name)
            if not name or name == "" then return end

            local ok, err = state_module.add_dir_link(parent_path, name, dir_path)
            if ok then
              -- Expand parent to show new dir_link
              local ui_state = state_module.load_ui_state()
              if not state_module.is_expanded(ui_state, parent_path) then
                state_module.toggle_expanded(parent_path)
              end
              vim.schedule(function()
                if mp_state and mp_state:is_valid() then
                  mp_state:render_panel("groups")
                end
              end)
            else
              logger.error(err or "Failed to add directory link")
            end
          end)
        end)
      end
    end)
  else
    -- Add item to current group
    -- Try to get group_path from element data first, then fallback to ui_state
    local group_path = nil
    local element = mp_state:get_element_at_cursor()
    if element and element.data and element.data.group_path then
      group_path = element.data.group_path
    else
      local ui_state = state_module.load_ui_state()
      group_path = ui_state.last_selected_group
    end

    if not group_path then
      logger.warn("Select a group first")
      return
    end

    -- Use nvim-float select popup
    dialogs.select("Add to " .. group_path, { "Current directory", "Current file", "Enter path..." }, function(idx, choice)
      if not choice then return end

      local path
      if choice == "Current directory" then
        path = vim.fn.getcwd()
      elseif choice == "Current file" then
        path = vim.fn.expand('%:p')
        if path == "" then
          logger.warn("No file in current buffer")
          return
        end
      else
        -- Show input popup for custom path
        dialogs.input("Add Path", "Path:", "", function(input)
          local ok, err = state_module.add_item(group_path, input)
          if ok then
            vim.schedule(function()
              if mp_state and mp_state:is_valid() then
                mp_state:render_panel("items")
              end
            end)
          else
            logger.error(err or "Failed to add item")
          end
        end)
        return
      end

      local ok, err = state_module.add_item(group_path, path)
      if ok then
        vim.schedule(function()
          if mp_state and mp_state:is_valid() then
            mp_state:render_panel("items")
          end
        end)
      else
        logger.error(err or "Failed to add item")
      end
    end)
  end
end

-- ============================================================================
-- Delete Handlers
-- ============================================================================

---Handle Delete key
---@param mp_state MultiPanelState
function M.handle_delete(mp_state)
  local focused = utils.get_focused_panel(mp_state)
  local element = mp_state:get_element_at_cursor()

  if not element or not element.data then return end

  if focused == "groups" then
    local node = element.data.node
    if not node then return end

    if node.is_dir_link then
      -- Delete directory link
      dialogs.confirm("Remove directory link '" .. node.name .. "'?", function()
        -- Get parent path from full_path
        local parent_path = path_utils.get_parent_path(node.full_path)

        local ok, err = state_module.remove_dir_link(parent_path, node.name)
        if ok then
          vim.schedule(function()
            if mp_state and mp_state:is_valid() then
              mp_state:render_panel("groups")
              mp_state:render_panel("items")
            end
          end)
        else
          logger.error(err or "Failed to remove directory link")
        end
      end)
    else
      -- Delete group
      dialogs.confirm("Delete group '" .. node.name .. "'?", function()
        local ok, err = state_module.remove_group(node.full_path)
        if ok then
          vim.schedule(function()
            if mp_state and mp_state:is_valid() then
              mp_state:render_panel("groups")
              mp_state:render_panel("items")
            end
          end)
        else
          logger.error(err or "Failed to delete group")
        end
      end)
    end
  else
    local item = element.data.item
    local group_path = element.data.group_path
    local index = element.data.index

    if not item or not group_path then return end

    local name = vim.fn.fnamemodify(item.path, ':t')

    dialogs.confirm("Remove '" .. name .. "' from group?", function()
      local ok, err = state_module.remove_item(group_path, index)
      if ok then
        vim.schedule(function()
          if mp_state and mp_state:is_valid() then
            mp_state:render_panel("items")
          end
        end)
      else
        logger.error(err or "Failed to remove item")
      end
    end)
  end
end

-- ============================================================================
-- Rename Handlers
-- ============================================================================

---Handle Rename key
---@param mp_state MultiPanelState
function M.handle_rename(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused == "groups" then
    local element = mp_state:get_element_at_cursor()
    if not element or not element.data then return end

    local node = element.data.node
    if not node then return end

    -- Directory links cannot be renamed (delete and re-add instead)
    if node.is_dir_link then
      logger.info("Cannot rename directory links (use 'd' to remove and 'a' to add)")
      return
    end

    dialogs.input("Rename Group", "New Name:", node.name, function(new_name)
      if new_name ~= node.name then
        local ok, err = state_module.rename_group(node.full_path, new_name)
        if ok then
          vim.schedule(function()
            if mp_state and mp_state:is_valid() then
              mp_state:render_panel("groups")
            end
          end)
        else
          logger.error(err or "Failed to rename group")
        end
      end
    end)
  else
    logger.info("Cannot rename items (use 'd' to remove and 'a' to add)")
  end
end

-- ============================================================================
-- Move Handlers
-- ============================================================================

---Handle Move key (for items)
---@param mp_state MultiPanelState
function M.handle_move(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused ~= "items" then
    logger.info("Move only works for items")
    return
  end

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  local from_group = element.data.group_path
  local index = element.data.index
  if not from_group then return end

  local groups = state_module.get_group_list()
  -- Filter out current group
  groups = vim.tbl_filter(function(g)
    return g ~= from_group
  end, groups)

  if #groups == 0 then
    logger.warn("No other groups to move to")
    return
  end

  dialogs.select("Move to group", groups, function(_, to_group)
    if to_group then
      local ok, err = state_module.move_item(from_group, index, to_group)
      if ok then
        logger.info("Moved to %s", to_group)
        vim.schedule(function()
          if mp_state and mp_state:is_valid() then
            mp_state:render_panel("items")
          end
        end)
      else
        logger.error(err or "Failed to move item")
      end
    end
  end)
end

---Handle Move Group key (move group to different parent)
---@param mp_state MultiPanelState
function M.handle_move_group(mp_state)
  local focused = utils.get_focused_panel(mp_state)

  if focused ~= "groups" then
    logger.info("Use 'm' to move items")
    return
  end

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  local node = element.data.node
  if not node then return end

  -- Directory links cannot be moved (delete and re-add instead)
  if node.is_dir_link then
    logger.info("Cannot move directory links (use 'd' to remove and 'a' to add)")
    return
  end

  local group_path = node.full_path

  -- Build list of possible destinations
  local all_groups = state_module.get_group_list()

  -- Filter out:
  -- 1. The group itself
  -- 2. Any children of the group (would create circular reference)
  -- 3. The current parent (no point moving to same location)
  local current_parent = path_utils.get_parent_path(group_path)

  local destinations = {}

  -- Add root level option (unless already at root)
  if current_parent ~= "" then
    table.insert(destinations, "(Root Level)")
  end

  -- Add valid group destinations
  for _, g in ipairs(all_groups) do
    -- Skip self, children of self, and current parent
    if g ~= group_path
        and not vim.startswith(g, group_path .. ".")
        and g ~= current_parent then
      table.insert(destinations, g)
    end
  end

  if #destinations == 0 then
    logger.warn("No valid destinations to move to")
    return
  end

  dialogs.select("Move '" .. node.name .. "' to", destinations, function(idx, dest)
    if dest then
      local new_parent = dest == "(Root Level)" and "" or dest
      local ok, err = state_module.move_group(group_path, new_parent)
      if ok then
        local dest_name = dest == "(Root Level)" and "root level" or dest
        logger.info("Moved '%s' to %s", node.name, dest_name)
        vim.schedule(function()
          if mp_state and mp_state:is_valid() then
            mp_state:render_panel("groups")
            mp_state:render_panel("items")
          end
        end)
      else
        logger.error(err or "Failed to move group")
      end
    end
  end)
end

return M
