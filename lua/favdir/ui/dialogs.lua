---@module favdir.ui.dialogs
---Input, select, and confirm popup dialogs for favdir

local M = {}

-- ============================================================================
-- Input Popups using nvim-float (with vim.ui fallbacks)
-- ============================================================================

---Show a text input popup using nvim-float Form or fallback to vim.ui.input
---@param title string Title of the popup
---@param label string Label for the input field
---@param default_value string? Default value
---@param on_submit fun(value: string) Callback with the entered value
---@param on_cancel fun()? Optional cancel callback
function M.show_input_popup(title, label, default_value, on_submit, on_cancel)
  local nvim_float = require("nvim-float")

  -- Try nvim-float form if available
  if nvim_float.create_form then
    nvim_float.create_form({
      title = " " .. title .. " ",
      width = 50,
      zindex = nvim_float.ZINDEX and nvim_float.ZINDEX.MODAL or 150,
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
  else
    -- Fallback to vim.ui.input
    vim.ui.input({
      prompt = label .. " ",
      default = default_value or "",
    }, function(value)
      if value and value ~= "" then
        on_submit(value)
      elseif on_cancel then
        on_cancel()
      end
    end)
  end
end

---Show a selection popup using nvim-float or fallback to vim.ui.select
---@param title string Title of the popup
---@param items string[] Items to select from
---@param on_select fun(index: number, item: string) Callback with selected item
function M.show_select_popup(title, items, on_select)
  local nvim_float = require("nvim-float")

  -- Try nvim-float select if available
  if nvim_float.select then
    nvim_float.select(items, on_select, title)
  else
    -- Fallback to vim.ui.select
    vim.ui.select(items, { prompt = title }, function(item, idx)
      if item then
        on_select(idx, item)
      end
    end)
  end
end

---Show a confirmation popup using nvim-float or fallback to vim.ui.select
---@param message string|string[] Message to display
---@param on_confirm fun() Callback on confirmation
---@param on_cancel fun()? Optional cancel callback
function M.show_confirm_popup(message, on_confirm, on_cancel)
  local nvim_float = require("nvim-float")

  -- Try nvim-float confirm if available
  if nvim_float.confirm then
    nvim_float.confirm(message, on_confirm, on_cancel)
  else
    -- Fallback to vim.ui.select
    local msg = type(message) == "table" and table.concat(message, " ") or message
    vim.ui.select({ "Yes", "No" }, { prompt = msg }, function(choice)
      if choice == "Yes" then
        on_confirm()
      elseif on_cancel then
        on_cancel()
      end
    end)
  end
end

return M
