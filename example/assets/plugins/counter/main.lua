-- Classic counter: pure Lua state; button handlers are Lua functions
-- (runtime registers reserved `action` events — no on_event required).
local count = 0

function render()
  return ui.Column {
    spacing = 12,
    crossAxisAlignment = enums.CrossAxisAlignmentPreset.stretch,
    children = {
      ui.Text { text = "Counter", size = enums.TextSize.large, weight = enums.FontWeightPreset.bold },
      ui.Text { text = "Count: " .. tostring(count), size = enums.TextSize.large, color = enums.TextColor.primary },
      ui.Button {
        text = "Increment (+1)",
        onPressed = function()
          count = count + 1
        end,
      },
      ui.Button {
        text = "Decrement (-1)",
        onPressed = function()
          count = count - 1
        end,
      },
      ui.Button {
        text = "Reset",
        onPressed = function()
          count = 0
        end,
      },
    },
  }
end
