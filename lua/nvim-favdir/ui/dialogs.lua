---@module favdir.ui.dialogs
---Input, select, and confirm popup dialogs using nvim-float

local M = {}

local nvim_float = require("nvim-float")

---Show a text input popup
---@param title string Title of the popup
---@param label string Label for the input field
---@param default_value string? Default value
---@param on_submit fun(value: string) Callback with the entered value
---@param on_cancel fun()? Optional cancel callback
function M.input(title, label, default_value, on_submit, on_cancel)
  nvim_float.create_form({
    title = " " .. title .. " ",
    width = 50,
    zindex = nvim_float.ZINDEX.MODAL,
    fields = {
      {
        name = "value",
        label = label,
        type = "text",
        value = default_value or "",
        placeholder = "Enter value...",
        width = 30,
      },
    },
    on_submit = function(values)
      if values.value and values.value ~= "" then
        on_submit(values.value)
      end
    end,
    on_cancel = on_cancel,
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
