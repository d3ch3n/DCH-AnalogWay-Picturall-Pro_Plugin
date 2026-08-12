local function AddControl(control)
  table.insert(ctrls, control)
end

local function GetProperty(name, fallback)
  if props[name] ~= nil and props[name].Value ~= nil then
    return props[name].Value
  end
  return fallback
end

local function PresetCount()
  local count = math.floor(tonumber(GetProperty("Preset Count", 8)) or 8)
  if count < 1 then
    return 1
  elseif count > 32 then
    return 32
  end
  return count
end

AddControl({Name = "IPAddress", ControlType = "Text", Count = 1})
AddControl({Name = "HTTPPort", ControlType = "Text", Count = 1})
AddControl({Name = "ScreenID", ControlType = "Text", Count = 1})
AddControl({Name = "CanvasIDs", ControlType = "Text", Count = 1})
AddControl({Name = "ConnectionActive", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "ConnectionStatus", ControlType = "Indicator", IndicatorType = "Status", Count = 1, IsReadOnly = true})
AddControl({Name = "StatusText", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "LastResponseCode", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "LastResponseBody", ControlType = "Text", Count = 1, IsReadOnly = true})

AddControl({Name = "NormalMode", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "BlackMode", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
AddControl({Name = "ModeNormalActive", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "ModeBlackActive", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "CurrentMode", ControlType = "Text", Count = 1, IsReadOnly = true})

for ix = 1, PresetCount() do
  AddControl({Name = "Preset" .. ix .. "Name", ControlType = "Text", Count = 1})
  AddControl({Name = "Preset" .. ix .. "Sequence", ControlType = "Text", Count = 1})
  AddControl({Name = "Preset" .. ix .. "Recall", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
  AddControl({Name = "Preset" .. ix .. "Active", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
end
