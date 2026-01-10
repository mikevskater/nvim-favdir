---@module favdir.ui.tree
---Tree building for favdir group hierarchy

local M = {}

local state_module = require("favdir.state")
local sort_comparators = require("favdir.state.sort_comparators")
local constants = require("favdir.constants")

-- ============================================================================
-- Type Definitions
-- ============================================================================

---@class TreeNode
---@field name string Display name
---@field full_path string Full group path (e.g., "Work.Projects")
---@field level number Indentation level (0-based)
---@field is_expanded boolean Whether expanded
---@field has_children boolean Whether has child groups or dir_links
---@field is_leaf boolean Whether this is a leaf (no children/dir_links)
---@field is_dir_link boolean Whether this is a directory link
---@field dir_path string? Filesystem path for dir_links
---@field group FavdirGroup? Reference to the group (nil for dir_links)
---@field dir_link FavdirDirLink? Reference to the dir_link (nil for groups)

-- ============================================================================
-- Tree Building
-- ============================================================================

---Build visible tree nodes from data
---@param data FavdirData
---@param ui_state FavdirUIState
---@return TreeNode[]
function M.build_tree(data, ui_state)
  local nodes = {}
  local left_sort_asc = ui_state.left_sort_asc ~= false -- default to true

  local function collect(groups, prefix, level)
    -- Sort by order
    local sorted = vim.tbl_values(groups)
    table.sort(sorted, sort_comparators.group_comparator("custom", left_sort_asc))

    for _, group in ipairs(sorted) do
      local path = prefix == "" and group.name or (prefix .. "." .. group.name)
      local has_children = (group.children and #group.children > 0)
        or (group.dir_links and #group.dir_links > 0)
      local is_expanded = state_module.is_expanded(ui_state, path)

      table.insert(nodes, {
        name = group.name,
        full_path = path,
        level = level,
        is_expanded = is_expanded,
        has_children = has_children,
        is_leaf = not has_children,
        is_dir_link = false,
        dir_path = nil,
        group = group,
        dir_link = nil,
      })

      -- Recursively add children and dir_links if expanded
      if is_expanded then
        -- Collect children and dir_links, sort together by order
        local child_items = {}

        if group.children then
          for _, child in ipairs(group.children) do
            table.insert(child_items, { type = constants.ITEM_TYPE.GROUP, item = child, order = child.order or 0 })
          end
        end

        if group.dir_links then
          for _, link in ipairs(group.dir_links) do
            table.insert(child_items, { type = constants.ITEM_TYPE.DIR_LINK, item = link, order = link.order or 0 })
          end
        end

        -- Sort by order
        table.sort(child_items, sort_comparators.mixed_children_comparator(left_sort_asc))

        for _, child_item in ipairs(child_items) do
          if child_item.type == constants.ITEM_TYPE.GROUP then
            -- Recursively collect this group
            collect({ child_item.item }, path, level + 1)
          else
            -- Add dir_link node
            local link = child_item.item
            local link_path = path .. "." .. link.name
            table.insert(nodes, {
              name = link.name,
              full_path = link_path,
              level = level + 1,
              is_expanded = false,
              has_children = false,
              is_leaf = true,
              is_dir_link = true,
              dir_path = link.path,
              group = nil,
              dir_link = link,
            })
          end
        end
      end
    end
  end

  collect(data.groups, "", 0)
  return nodes
end

return M
