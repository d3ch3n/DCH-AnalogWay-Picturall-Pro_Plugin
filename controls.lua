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
  local count = math.floor(tonumber(GetProperty("Preset Count", 5)) or 5)
  if count < 1 then
    return 1
  elseif count > 24 then
    return 24
  end
  return count
end

local function PlaybackCount()
  local count = math.floor(tonumber(GetProperty("Playback Count", 8)) or 8)
  if count < 1 then
    return 1
  elseif count > 8 then
    return 8
  end
  return count
end

AddControl({Name = "IPAddress", ControlType = "Text", Count = 1})
AddControl({Name = "TCPPort", ControlType = "Text", Count = 1})
AddControl({Name = "ConnectionActive", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
AddControl({Name = "ConnectionStatus", ControlType = "Indicator", IndicatorType = "Status", Count = 1, IsReadOnly = true})
AddControl({Name = "StatusText", ControlType = "Text", Count = 1, IsReadOnly = true})

AddControl({Name = "ServerVersion", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "ActivePlayback", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "ActiveCueStack", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "ActiveCue", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "PlaybackState", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "CommandStatus", ControlType = "Text", Count = 1, IsReadOnly = true})
AddControl({Name = "PollFeedback", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})

for ix = 1, PlaybackCount() do
  AddControl({Name = "Playback" .. ix .. "GoCommand", ControlType = "Text", Count = 1})
  AddControl({Name = "Playback" .. ix .. "Go", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
  AddControl({Name = "Playback" .. ix .. "Active", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
end

for ix = 1, PresetCount() do
  AddControl({Name = "Preset" .. ix .. "Name", ControlType = "Text", Count = 1})
  AddControl({Name = "Preset" .. ix .. "Command", ControlType = "Text", Count = 1})
  AddControl({Name = "Preset" .. ix .. "CueStack", ControlType = "Text", Count = 1})
  AddControl({Name = "Preset" .. ix .. "Playback", ControlType = "Text", Count = 1})
  AddControl({Name = "Preset" .. ix .. "Go", ControlType = "Button", ButtonType = "Trigger", Count = 1, UserPin = true, PinStyle = "Input"})
  AddControl({Name = "Preset" .. ix .. "Active", ControlType = "Indicator", IndicatorType = "Led", Count = 1, IsReadOnly = true})
end
