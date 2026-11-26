-- TextField + Apply: form values buffer on the host until Apply flushes them.
local draft = ""
local label = "(nothing applied yet)"

function flush_state(fields)
  if fields.draft ~= nil then
    draft = fields.draft
  end
end

function render()
  return ui.Column {
    spacing = 12,
    crossAxisAlignment = enums.CrossAxisAlignmentPreset.stretch,
    children = {
      ui.Text {
        text = "Echo form",
        size = enums.TextSize.large,
        weight = enums.FontWeightPreset.bold,
      },
      ui.TextField {
        id = "draft",
        label = "Message",
        value = draft,
      },
      ui.Button {
        text = "Apply",
        onPressed = function()
          label = draft
        end,
      },
      ui.Text {
        text = "Applied: " .. label,
        size = enums.TextSize.large,
        color = enums.TextColor.primary,
      },
    },
  }
end
