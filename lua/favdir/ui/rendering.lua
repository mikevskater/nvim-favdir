---@module favdir.ui.rendering
---Facade module that re-exports tree building and panel rendering functions
---
---This module delegates to focused submodules:
---  - favdir.ui.tree - Tree building (build_tree, TreeNode type)
---  - favdir.ui.rendering.panels - Panel rendering (render_left_panel, render_right_panel)
---  - favdir.ui.rendering.directory - Directory contents rendering (render_dir_link_contents)
---  - favdir.ui.rendering.interactions - Element interaction handlers (on_group_interact, on_item_interact)

local M = {}

local tree = require("favdir.ui.tree")
local panels = require("favdir.ui.rendering.panels")
local directory = require("favdir.ui.rendering.directory")
local interactions = require("favdir.ui.rendering.interactions")

-- Re-export tree functions
M.build_tree = tree.build_tree

-- Re-export panel rendering functions
M.render_left_panel = panels.render_left_panel
M.render_right_panel = panels.render_right_panel

-- Re-export directory rendering
M.render_dir_link_contents = directory.render_dir_link_contents

-- Re-export interaction handlers
M.on_group_interact = interactions.on_group_interact
M.on_item_interact = interactions.on_item_interact

return M
