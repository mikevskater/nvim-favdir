---@module favdir.ui.handlers.editing
---Editing handlers for favdir (add, delete, rename, move)

local M = {}

local state_module = require("favdir.state")
local dialogs = require("favdir.ui.dialogs")

-- ============================================================================
-- Add Handlers
-- ============================================================================

---Handle Add key
---@param mp_state MultiPanelState
function M.handle_add(mp_state)
  local focused = mp_state.focused_panel

  if focused == "groups" then
    local element = mp_state:get_element_at_cursor()
    local node = element and element.data and element.data.node

    -- If cursor is on a dir_link, we can't add children to it
    if node and node.is_dir_link then
      vim.notify("Cannot add children to a directory link", vim.log.levels.WARN)
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
            vim.notify(err or "Failed to add group", vim.log.levels.ERROR)
          end
        end)
      else
        -- Add directory link
        if parent_path == "" then
          vim.notify("Directory links must be added inside a group", vim.log.levels.WARN)
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
              vim.notify(err or "Failed to add directory link", vim.log.levels.ERROR)
            end
          end)
        end)
      end
    end)
  else
    -- Add item to current group
    local ui_state = state_module.load_ui_state()
    local group_path = ui_state.last_selected_group

    if not group_path then
      vim.notify("Select a group first", vim.log.levels.WARN)
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
          vim.notify("No file in current buffer", vim.log.levels.WARN)
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
            vim.notify(err or "Failed to add item", vim.log.levels.ERROR)
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
        vim.notify(err or "Failed to add item", vim.log.levels.ERROR)
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
  local focused = mp_state.focused_panel
  local element = mp_state:get_element_at_cursor()

  if not element or not element.data then return end

  if focused == "groups" then
    local node = element.data.node
    if not node then return end

    if node.is_dir_link then
      -- Delete directory link
      dialogs.confirm("Remove directory link '" .. node.name .. "'?", function()
        -- Get parent path from full_path
        local parts = vim.split(node.full_path, ".", { plain = true })
        table.remove(parts) -- Remove the dir_link name
        local parent_path = table.concat(parts, ".")

        local ok, err = state_module.remove_dir_link(parent_path, node.name)
        if ok then
          vim.schedule(function()
            if mp_state and mp_state:is_valid() then
              mp_state:render_panel("groups")
              mp_state:render_panel("items")
            end
          end)
        else
          vim.notify(err or "Failed to remove directory link", vim.log.levels.ERROR)
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
          vim.notify(err or "Failed to delete group", vim.log.levels.ERROR)
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
        vim.notify(err or "Failed to remove item", vim.log.levels.ERROR)
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
  local focused = mp_state.focused_panel

  if focused == "groups" then
    local element = mp_state:get_element_at_cursor()
    if not element or not element.data then return end

    local node = element.data.node
    if not node then return end

    -- Directory links cannot be renamed (delete and re-add instead)
    if node.is_dir_link then
      vim.notify("Cannot rename directory links (use 'd' to remove and 'a' to add)", vim.log.levels.INFO)
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
          vim.notify(err or "Failed to rename group", vim.log.levels.ERROR)
        end
      end
    end)
  else
    vim.notify("Cannot rename items (use 'd' to remove and 'a' to add)", vim.log.levels.INFO)
  end
end

-- ============================================================================
-- Move Handlers
-- ============================================================================

---Handle Move key (for items)
---@param mp_state MultiPanelState
function M.handle_move(mp_state)
  local focused = mp_state.focused_panel

  if focused ~= "items" then
    vim.notify("Move only works for items", vim.log.levels.INFO)
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
    vim.notify("No other groups to move to", vim.log.levels.WARN)
    return
  end

  dialogs.select("Move to group", groups, function(_, to_group)
    if to_group then
      local ok, err = state_module.move_item(from_group, index, to_group)
      if ok then
        vim.notify("Moved to " .. to_group, vim.log.levels.INFO)
        vim.schedule(function()
          if mp_state and mp_state:is_valid() then
            mp_state:render_panel("items")
          end
        end)
      else
        vim.notify(err or "Failed to move item", vim.log.levels.ERROR)
      end
    end
  end)
end

---Handle Move Group key (move group to different parent)
---@param mp_state MultiPanelState
function M.handle_move_group(mp_state)
  local focused = mp_state.focused_panel

  if focused ~= "groups" then
    vim.notify("Use 'm' to move items", vim.log.levels.INFO)
    return
  end

  local element = mp_state:get_element_at_cursor()
  if not element or not element.data then return end

  local node = element.data.node
  if not node then return end

  -- Directory links cannot be moved (delete and re-add instead)
  if node.is_dir_link then
    vim.notify("Cannot move directory links (use 'd' to remove and 'a' to add)", vim.log.levels.INFO)
    return
  end

  local group_path = node.full_path

  -- Build list of possible destinations
  local all_groups = state_module.get_group_list()

  -- Filter out:
  -- 1. The group itself
  -- 2. Any children of the group (would create circular reference)
  -- 3. The current parent (no point moving to same location)
  local current_parent = ""
  local parts = vim.split(group_path, ".", { plain = true })
  if #parts > 1 then
    table.remove(parts)
    current_parent = table.concat(parts, ".")
  end

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
    vim.notify("No valid destinations to move to", vim.log.levels.WARN)
    return
  end

  dialogs.select("Move '" .. node.name .. "' to", destinations, function(idx, dest)
    if dest then
      local new_parent = dest == "(Root Level)" and "" or dest
      local ok, err = state_module.move_group(group_path, new_parent)
      if ok then
        local dest_name = dest == "(Root Level)" and "root level" or dest
        vim.notify("Moved '" .. node.name .. "' to " .. dest_name, vim.log.levels.INFO)
        vim.schedule(function()
          if mp_state and mp_state:is_valid() then
            mp_state:render_panel("groups")
            mp_state:render_panel("items")
          end
        end)
      else
        vim.notify(err or "Failed to move group", vim.log.levels.ERROR)
      end
    end
  end)
end

return M
