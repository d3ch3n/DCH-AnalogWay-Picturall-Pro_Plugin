local HeaderFill = {225,225,225}
local BodyFill = {230,230,230}
local PanelStroke = {30,30,30}
local ButtonGray = {105,105,105}
local ButtonBlue = {0,185,230}
local ButtonBlack = {35,35,35}
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
  local count = math.floor(tonumber(GetProperty("Preset Count", 8)) or 8)
  if count < 1 then
    return 1
  elseif count > 32 then
    return 32
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

local function AddButton(name, x, y, w, h, legend, color)
  layout[name] = {
    PrettyName = name,
    Legend = legend,
    Style = "Button",
    ButtonStyle = "Trigger",
    Color = color or ButtonGray,
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
  AddText("DCH", 28, 28, 64, 22, 16, "Left")
  AddText("NovaStar KC40", 188, 28, 146, 22, 15)
  AddText("Preset / Display Mode", 180, 54, 162, 16, 9)
  AddText("IP ADDRESS", 20, 84, 92, 12, 8, "Left")
  AddText("PORT", 124, 84, 36, 12, 8, "Left")
  AddText("STATUS", 174, 84, 108, 12, 8, "Left")
  AddTextControl("IPAddress", 22, 100, 96, 23, "Text")
  AddTextControl("HTTPPort", 124, 100, 42, 23, "Text")
  layout["ConnectionStatus"] = {PrettyName = "ConnectionStatus", Style = "Status", Position = {174,100}, Size = {170,23}, FontSize = 8}
  AddLed("ConnectionActive", 365, 104, Green)
  AddText("HTTP", 386, 103, 46, 16, 8, "Left")
end

local function AddPresetRow(ix, y)
  AddText(tostring(ix), 58, y + 6, 20, 14, 8, "Center")
  AddTextControl("Preset" .. ix .. "Name", 86, y, 118, 23, "Text")
  AddTextControl("Preset" .. ix .. "Sequence", 212, y, 58, 23, "Text")
  AddButton("Preset" .. ix .. "Recall", 286, y, 74, 23, "Recall", ButtonBlue)
  AddLed("Preset" .. ix .. "Active", 372, y + 4, Green)
end

local function AddControlPage()
  AddHeader()
  AddGroupBox("TARGET", 44, 160, 438, 72)
  AddText("SCREEN ID", 64, 192, 80, 12, 8, "Left")
  AddTextControl("ScreenID", 64, 206, 160, 23, "Text")
  AddText("CANVAS IDS", 254, 192, 80, 12, 8, "Left")
  AddTextControl("CanvasIDs", 254, 206, 160, 23, "Text")

  AddGroupBox("DISPLAY MODE", 44, 254, 438, 112)
  AddButton("NormalMode", 70, 298, 112, 34, "Normal", ButtonBlue)
  AddLed("ModeNormalActive", 190, 307, Green)
  AddButton("BlackMode", 234, 298, 112, 34, "Black", ButtonBlack)
  AddLed("ModeBlackActive", 354, 307, Green)
  AddText("CURRENT MODE", 70, 342, 110, 12, 8, "Left")
  AddTextControl("CurrentMode", 190, 338, 156, 24, "Textdisplay")

  AddGroupBox("PRESETS", 44, 388, 438, 260)
  AddText("#", 58, 416, 20, 12, 8)
  AddText("NAME", 86, 416, 118, 12, 8, "Left")
  AddText("SEQ", 212, 416, 58, 12, 8)
  for ix = 1, PresetCount() do
    local y = 434 + ((ix - 1) * 26)
    if y <= 622 then
      AddPresetRow(ix, y)
    end
  end
end

local function AddTechnicalPage()
  AddHeader()
  AddGroupBox("LAST RESPONSE", 44, 160, 438, 150)
  AddText("HTTP CODE", 70, 196, 80, 12, 8, "Left")
  AddTextControl("LastResponseCode", 70, 212, 80, 24, "Textdisplay")
  AddText("BODY", 70, 252, 80, 12, 8, "Left")
  AddTextControl("LastResponseBody", 70, 268, 360, 24, "Textdisplay")

  AddGroupBox("PROTOCOL", 44, 340, 438, 170)
  AddText("COEX API uses HTTP on port 8001 in online mode.", 66, 378, 390, 18, 9, "Left")
  AddText("Preset recall: POST /api/v1/preset/current/update.", 66, 406, 390, 18, 9, "Left")
  AddText("Normal/Black: PUT /api/v1/device/displaymode.", 66, 434, 390, 18, 9, "Left")
end

local CurrentPage = PageNames[props["page_index"].Value]
if CurrentPage == "Control" then
  AddControlPage()
elseif CurrentPage == "Technical" then
  AddTechnicalPage()
end
