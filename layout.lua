--[[ #include "image_assets.lua" ]]

local HeaderFill = {225,225,225}
local BodyFill = {230,230,230}
local PanelStroke = {30,30,30}
local ButtonGray = {105,105,105}
local ButtonBlue = {0,185,230}
local Green = {0,145,0}
local PageWidth = 518
local PageHeight = 690

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

local function AddText(text, x, y, w, h, size, align)
  table.insert(graphics,{
    Type = "Text",
    Text = text,
    Position = {x,y},
    Size = {w,h},
    FontSize = size or 9,
    HTextAlign = align or "Center"
  })
end

local function AddButton(name, x, y, w, h, legend, color, style)
  layout[name] = {
    PrettyName = name,
    Legend = legend,
    Style = "Button",
    ButtonStyle = style or "Trigger",
    Color = color or ButtonGray,
    OffColor = ButtonGray,
    UnlinkOffColor = true,
    Position = {x,y},
    Size = {w,h},
    FontSize = 9
  }
end

local function AddTextControl(name, x, y, w, h, style)
  layout[name] = {
    PrettyName = name,
    Style = style or "Text",
    Position = {x,y},
    Size = {w,h},
    FontSize = 8
  }
end

local function AddLed(name, x, y, color)
  layout[name] = {
    PrettyName = name,
    Style = "Led",
    Color = color or Green,
    Position = {x,y},
    Size = {16,16}
  }
end

local function AddGroupBox(title, x, y, w, h, fill)
  table.insert(graphics,{
    Type = "GroupBox",
    Text = title,
    Fill = fill or BodyFill,
    StrokeWidth = 1,
    StrokeColor = PanelStroke,
    Position = {x,y},
    Size = {w,h}
  })
end

local function AddHeader()
  table.insert(graphics,{Type = "GroupBox", Fill = HeaderFill, StrokeWidth = 1, StrokeColor = PanelStroke, Position = {0,0}, Size = {PageWidth,PageHeight}})
  table.insert(graphics,{Type = "GroupBox", Fill = BodyFill, StrokeWidth = 0, Position = {10,140}, Size = {PageWidth - 20,PageHeight - 150}})
  AddGroupBox("HEADER", 10, 10, PageWidth - 20, 120, HeaderFill)
  table.insert(graphics,{Type = "Image", Image = DechenLogo, Position = {20,20}, Size = {140,45}})
  AddText("Analog Way", 188, 28, 142, 18, 12)
  AddText("Picturall Pro", 178, 48, 162, 24, 15)
  AddText("Cue Stack Controller", 184, 72, 150, 16, 9)
  AddText("IP ADDRESS", 20, 74, 92, 14, 8, "Left")
  AddText("PORT", 118, 74, 30, 14, 8, "Left")
  AddText("STATUS", 150, 74, 108, 14, 8, "Left")
  AddTextControl("IPAddress", 22, 90, 92, 25, "Text")
  AddTextControl("TCPPort", 118, 90, 28, 25, "Text")
  AddTextControl("StatusText", 150, 90, 110, 25, "Textdisplay")
  AddLed("ConnectionActive", 385, 95, Green)
  AddText("TCP", 406, 94, 34, 16, 8, "Left")
  layout["ConnectionStatus"] = {PrettyName = "ConnectionStatus", Style = "Status", Position = {270,90}, Size = {102,25}, FontSize = 8}
end

local function AddPresetRow(ix, y)
  AddText(tostring(ix), 52, y + 7, 20, 14, 8, "Center")
  AddTextControl("Preset" .. ix .. "Name", 78, y, 96, 25, "Text")
  AddTextControl("Preset" .. ix .. "Playback", 180, y, 34, 25, "Text")
  AddTextControl("Preset" .. ix .. "CueStack", 220, y, 62, 25, "Text")
  AddTextControl("Preset" .. ix .. "Command", 288, y, 120, 25, "Text")
  AddButton("Preset" .. ix .. "Go", 416, y, 42, 25, "Go", ButtonBlue)
  AddLed("Preset" .. ix .. "Active", 464, y + 4, Green)
end

local function AddPlaybackRow(ix, x, y)
  AddButton("Playback" .. ix .. "Go", x, y, 42, 25, "PB " .. ix, ButtonBlue)
  AddLed("Playback" .. ix .. "Active", x + 48, y + 4, Green)
  AddTextControl("Playback" .. ix .. "GoCommand", x + 70, y, 118, 25, "Text")
end

local function AddControlPage()
  AddHeader()
  AddGroupBox("CONNECTION / STATUS", 44, 160, 438, 110)
  AddText("SERVER VERSION", 64, 194, 110, 14, 8, "Left")
  AddTextControl("ServerVersion", 186, 190, 104, 24, "Textdisplay")
  AddText("PLAYBACK", 64, 226, 110, 14, 8, "Left")
  AddTextControl("ActivePlayback", 186, 222, 54, 24, "Textdisplay")
  AddText("CUE STACK", 252, 226, 72, 14, 8, "Left")
  AddTextControl("ActiveCueStack", 324, 222, 70, 24, "Textdisplay")
  AddText("CUE", 64, 252, 110, 14, 8, "Left")
  AddTextControl("ActiveCue", 186, 248, 54, 24, "Textdisplay")
  AddText("STATE", 252, 252, 72, 14, 8, "Left")
  AddTextControl("PlaybackState", 324, 248, 118, 24, "Textdisplay")

  AddGroupBox("CUE STACKS / PRESETS", 44, 292, 438, 356)
  AddText("#", 52, 322, 20, 14, 8)
  AddText("NAME", 78, 322, 96, 14, 8, "Left")
  AddText("PB", 180, 322, 34, 14, 8)
  AddText("STACK", 220, 322, 62, 14, 8)
  AddText("COMMAND", 288, 322, 120, 14, 8, "Left")
  for ix = 1, PresetCount() do
    local y = 342 + ((ix - 1) * 30)
    if y <= 612 then
      AddPresetRow(ix, y)
    end
  end
end

local function AddTechnicalPage()
  AddHeader()
  AddGroupBox("PLAYBACK GO", 44, 160, 438, 156)
  AddText("GO", 64, 186, 42, 12, 8)
  AddText("COMMAND", 134, 186, 118, 12, 8, "Left")
  AddText("GO", 274, 186, 42, 12, 8)
  AddText("COMMAND", 344, 186, 118, 12, 8, "Left")
  for ix = 1, PlaybackCount() do
    local col = (ix - 1) % 2
    local row = math.floor((ix - 1) / 2)
    AddPlaybackRow(ix, 64 + (col * 210), 202 + (row * 28))
  end

  AddGroupBox("TECHNICAL", 44, 338, 438, 154)
  AddButton("PollFeedback", 74, 204, 120, 34, "Poll Feedback", ButtonBlue)
  layout["PollFeedback"].Position = {74, 374}
  AddText("COMMAND", 222, 368, 116, 14, 8, "Left")
  AddTextControl("CommandStatus", 222, 386, 200, 24, "Textdisplay")
  AddText("ACTIVE PLAYBACK", 74, 436, 126, 14, 8, "Left")
  AddTextControl("ActivePlayback", 222, 432, 60, 24, "Textdisplay")
  AddText("ACTIVE CUE STACK", 74, 468, 126, 14, 8, "Left")
  AddTextControl("ActiveCueStack", 222, 464, 100, 24, "Textdisplay")

  AddGroupBox("PROTOCOL NOTE", 44, 526, 438, 126)
  AddText("Picturall uses a text based TCP/IP external control protocol on port 11000.", 64, 560, 388, 20, 9, "Left")
  AddText("Use Picturall Commander logging or Companion Learn to capture exact custom commands.", 64, 590, 388, 20, 9, "Left")
  AddText("Playback Go buttons send their configured PlaybackXGoCommand text.", 64, 620, 388, 20, 9, "Left")
end

local CurrentPage = PageNames[props["page_index"].Value]
if CurrentPage == "Control" then
  AddControlPage()
elseif CurrentPage == "Technical" then
  AddTechnicalPage()
end
