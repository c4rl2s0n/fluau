-- Classic counter: pure Lua state, no host permissions or capabilities.
local count = 0

function render()
  return ui.Column {
    spacing = 12,
    crossAxisAlignment = enums.CrossAxisAlignmentPreset.stretch,
    children = {
      ui.Text { text = "Counter", size = enums.TextSize.large, weight = enums.FontWeightPreset.bold },
      ui.Text { text = "Count: " .. tostring(count), size = enums.TextSize.large, color = enums.TextColor.primary },
      ui.Button { text = "Increment (+1)", onPressed = { type = "increment" } },
      ui.Button { text = "Decrement (-1)", onPressed = { type = "decrement" } },
      ui.Button { text = "Reset", onPressed = { type = "reset" } },
    },
  }
end

function on_event(event)
  if event.type == "increment" then
    count = count + 1
  elseif event.type == "decrement" then
    count = count - 1
  elseif event.type == "reset" then
    count = 0
  end
  return {}
end
