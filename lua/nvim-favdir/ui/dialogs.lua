---@module favdir.ui.dialogs
---Input, select, and confirm popup dialogs using nvim-float

local M = {}

local nvim_float = require("nvim-float")

---Show a text input popup with embedded input container
---@param title string Title of the popup
---@param label string Label for the input field
---@param default_value string? Default value
---@param on_submit fun(value: string) Callback with the entered value
---@param on_cancel fun()? Optional cancel callback
function M.input(title, label, default_value, on_submit, on_cancel)
  local UiFloat = require("nvim-float.window")
  local ContentBuilder = require("nvim-float.content")

  local cb = ContentBuilder.new()
  cb:blank()
  cb:embedded_input("value", {
    label = "  " .. label,
    value = default_value or "",
    placeholder = "Enter value...",
    width = 30,
    on_submit = function(_, v)
      if v and v ~= "" then
        -- Close the float first
        if M._current_input_float then
          M._current_input_float:close()
          M._current_input_float = nil
        end
        on_submit(v)
      end
    end,
  })
  cb:blank()

  -- Help text
  cb:spans({
    { text = "  ", style = "text" },
    { text = "Enter", style = "key" },
    { text = " Submit  ", style = "muted" },
    { text = "Esc", style = "key" },
    { text = " Cancel", style = "muted" },
  })
  cb:blank()

  local function cancel()
    if M._current_input_float then
      M._current_input_float:close()
      M._current_input_float = nil
    end
    if on_cancel then
      on_cancel()
    end
  end

  M._current_input_float = UiFloat.create(nil, {
    title = " " .. title .. " ",
    title_pos = "center",
    border = "rounded",
    width = 50,
    centered = true,
    zindex = nvim_float.ZINDEX.MODAL,
    default_keymaps = false,
    content_builder = cb,
    keymaps = {
      ["<Esc>"] = cancel,
      ["q"] = cancel,
    },
  })
end

---Show a selection popup
---@param title string Title of the popup
---@param items string[] Items to select from
---@param on_select fun(index: number, item: string) Callback with selected item
function M.select(title, items, on_select)
  nvim_float.select(items, on_select, title)
end

---Show a confirmation popup
---@param message string|string[] Message to display
---@param on_confirm fun() Callback on confirmation
---@param on_cancel fun()? Optional cancel callback
function M.confirm(message, on_confirm, on_cancel)
  nvim_float.confirm(message, on_confirm, on_cancel)
end

return M
