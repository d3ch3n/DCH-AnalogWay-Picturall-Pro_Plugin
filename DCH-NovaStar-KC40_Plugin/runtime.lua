-- NovaStar KC40 / COEX HTTP API control.
--
-- Official COEX documentation:
-- * Online device API uses HTTP on port 8001.
-- * Apply preset: POST /api/v1/preset/current/update
--   Body: {"sequenceNumber":0,"screenID":"string"}
-- * Set normal/black/freeze display mode: PUT /api/v1/device/displaymode
--   Body: {"value":0,"canvasIDs":[45]}
--
-- The public displaymode page documents the endpoint and body shape, but does
-- not publish a value table. For that reason, Normal Mode Value and Black Mode
-- Value are exposed as properties. Defaults are 0 and 1 and can be changed
-- after validating against the target KC40/VMP version.

local DefaultPort = 8001
local DefaultTimeout = 5

local Status = {
  OK = 0,
  Compromised = 1,
  Fault = 2,
  NotPresent = 3,
  Missing = 4,
  Initializing = 5
}

local socket = nil
local timeoutTimer = Timer.New()
local retryTimer = Timer.New()
local queue = {}
local currentRequest = nil
local rxBuffer = ""
local socketConnected = false
local activePreset = nil
local currentMode = ""

local function HasControl(name)
  return Controls[name] ~= nil
end

local function Control(name)
  return Controls[name]
end

local function GetProperty(name, fallback)
  if Properties and Properties[name] ~= nil and Properties[name].Value ~= nil then
    return Properties[name].Value
  end
  return fallback
end

local function DebugLevel()
  return tostring(GetProperty("Debug Level", "None"))
end

local function DebugPrint(level, message)
  local selected = DebugLevel()
  if selected == "All" or selected == level or (selected == "Tx/Rx" and (level == "Tx" or level == "Rx")) then
    print(message)
  end
end

local function SetStatus(code, text)
  if HasControl("ConnectionStatus") then
    Control("ConnectionStatus").Value = code
  end
  if HasControl("StatusText") then
    Control("StatusText").String = text
  end
end

local function SetConnected(state)
  socketConnected = state and true or false
  if HasControl("ConnectionActive") then
    Control("ConnectionActive").Boolean = socketConnected
  end
end

local function SetControlString(name, value)
  if HasControl(name) then
    Control(name).String = tostring(value or "")
  end
end

local function SetControlBoolean(name, value)
  if HasControl(name) then
    local state = value and true or false
    Control(name).Boolean = state
    Control(name).Value = state and 1 or 0
    Control(name).Position = state and 1 or 0
  end
end

local function Trim(value)
  value = tostring(value or "")
  value = string.gsub(value, "^%s+", "")
  value = string.gsub(value, "%s+$", "")
  return value
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

local function Port()
  local value = DefaultPort
  if HasControl("HTTPPort") and tonumber(Control("HTTPPort").String) ~= nil then
    value = math.floor(tonumber(Control("HTTPPort").String))
  else
    value = tonumber(GetProperty("HTTP Port", DefaultPort)) or DefaultPort
  end
  if value < 1 or value > 65535 then
    value = DefaultPort
  end
  return value
end

local function IPAddress()
  if HasControl("IPAddress") and Trim(Control("IPAddress").String) ~= "" then
    return Trim(Control("IPAddress").String)
  end
  return tostring(GetProperty("IP Address", ""))
end

local function ScreenID()
  if HasControl("ScreenID") and Trim(Control("ScreenID").String) ~= "" then
    return Trim(Control("ScreenID").String)
  end
  return tostring(GetProperty("Screen ID", ""))
end

local function CanvasIDs()
  if HasControl("CanvasIDs") and Trim(Control("CanvasIDs").String) ~= "" then
    return Trim(Control("CanvasIDs").String)
  end
  return tostring(GetProperty("Canvas IDs", "1"))
end

local function ResponseTimeout()
  return tonumber(GetProperty("Response Timeout", DefaultTimeout)) or DefaultTimeout
end

local function RetryCount()
  return tonumber(GetProperty("Retry Count", 1)) or 1
end

local function RetryDelay()
  return tonumber(GetProperty("Retry Delay", 5)) or 5
end

local function NormalModeValue()
  return math.floor(tonumber(GetProperty("Normal Mode Value", 0)) or 0)
end

local function BlackModeValue()
  return math.floor(tonumber(GetProperty("Black Mode Value", 1)) or 1)
end

local function JsonString(value)
  value = tostring(value or "")
  value = string.gsub(value, "\\", "\\\\")
  value = string.gsub(value, "\"", "\\\"")
  return "\"" .. value .. "\""
end

local function CanvasIDArray()
  local ids = {}
  local text = CanvasIDs()
  for item in string.gmatch(text, "[^,%s]+") do
    local numeric = tonumber(item)
    if numeric ~= nil then
      table.insert(ids, tostring(math.floor(numeric)))
    end
  end
  if #ids == 0 then
    table.insert(ids, "1")
  end
  return "[" .. table.concat(ids, ",") .. "]"
end

local function BuildHttpRequest(method, path, body)
  body = body or ""
  return table.concat({
    method .. " " .. path .. " HTTP/1.1",
    "Host: " .. IPAddress() .. ":" .. Port(),
    "Content-Type: application/json",
    "Accept: application/json",
    "Connection: close",
    "Content-Length: " .. #body,
    "",
    body
  }, "\r\n")
end

local function ApplyActiveFeedback()
  for ix = 1, PresetCount() do
    SetControlBoolean("Preset" .. ix .. "Active", activePreset == ix)
  end
  SetControlBoolean("ModeNormalActive", currentMode == "Normal")
  SetControlBoolean("ModeBlackActive", currentMode == "Black")
  SetControlString("CurrentMode", currentMode)
end

local function ParseHttpResponse(data)
  local statusCode = string.match(data, "^HTTP/%d%.%d%s+(%d+)")
  local body = string.match(data, "\r\n\r\n(.*)") or ""
  SetControlString("LastResponseCode", statusCode or "")
  SetControlString("LastResponseBody", body)
  DebugPrint("Rx", "RX HTTP " .. tostring(statusCode or ""))
  DebugPrint("Rx", body)

  local numericCode = tonumber(statusCode) or 0
  local apiCode = tonumber(string.match(body, "\"code\"%s*:%s*(-?%d+)"))
  local ok = numericCode >= 200 and numericCode < 300 and (apiCode == nil or apiCode == 0)
  if ok then
    SetStatus(Status.OK, "OK")
    if currentRequest ~= nil and currentRequest.onSuccess ~= nil then
      currentRequest.onSuccess()
    end
  else
    SetStatus(Status.Fault, "HTTP/API Error")
  end
  ApplyActiveFeedback()
end

CommandQueue = {}

function CommandQueue.Add(item)
  table.insert(queue, item)
  CommandQueue.Process()
end

function CommandQueue.Process()
  if currentRequest ~= nil then
    return
  end
  currentRequest = table.remove(queue, 1)
  if currentRequest == nil then
    return
  end
  CommandQueue.SendCurrent()
end

function CommandQueue.SendCurrent()
  if currentRequest == nil then
    return
  end
  local ip = IPAddress()
  if ip == "" then
    SetStatus(Status.Missing, "Missing IP Address")
    currentRequest = nil
    return
  end

  socket = TcpSocket.New()
  socket.EventHandler = function(sock, event, err)
    if event == TcpSocket.Events.Connected then
      SetConnected(true)
      SetStatus(Status.Compromised, "Sending")
      DebugPrint("Function Calls", "Connected to " .. ip .. ":" .. Port())
      DebugPrint("Tx", currentRequest.raw)
      sock:Write(currentRequest.raw)
    elseif event == TcpSocket.Events.Data then
      rxBuffer = rxBuffer .. sock:Read(sock.BufferLength)
    elseif event == TcpSocket.Events.Closed then
      timeoutTimer:Stop()
      ParseHttpResponse(rxBuffer)
      rxBuffer = ""
      currentRequest = nil
      SetConnected(false)
      CommandQueue.Process()
    elseif event == TcpSocket.Events.Error or event == TcpSocket.Events.Timeout then
      timeoutTimer:Stop()
      SetConnected(false)
      if currentRequest ~= nil and currentRequest.retries < RetryCount() then
        currentRequest.retries = currentRequest.retries + 1
        retryTimer:Start(RetryDelay())
      else
        SetStatus(Status.Fault, err or "Connection Error")
        currentRequest = nil
        CommandQueue.Process()
      end
    end
  end

  rxBuffer = ""
  SetStatus(Status.Compromised, "Connecting")
  socket:Connect(ip, Port())
  timeoutTimer:Start(ResponseTimeout())
end

function CommandQueue.Timeout()
  if socket ~= nil then
    socket.EventHandler = nil
    socket:Disconnect()
  end
  SetConnected(false)
  if currentRequest ~= nil and currentRequest.retries < RetryCount() then
    currentRequest.retries = currentRequest.retries + 1
    retryTimer:Start(RetryDelay())
  else
    SetStatus(Status.Fault, "Response timeout")
    currentRequest = nil
    CommandQueue.Process()
  end
end

local function QueueHttp(method, path, body, label, onSuccess)
  CommandQueue.Add({
    raw = BuildHttpRequest(method, path, body),
    label = label,
    onSuccess = onSuccess,
    retries = 0
  })
end

local function RecallPreset(ix)
  local sequence = ix - 1
  if HasControl("Preset" .. ix .. "Sequence") and tonumber(Control("Preset" .. ix .. "Sequence").String) ~= nil then
    sequence = math.floor(tonumber(Control("Preset" .. ix .. "Sequence").String))
  end
  local screenID = ScreenID()
  if screenID == "" then
    SetStatus(Status.Missing, "Missing Screen ID")
    return
  end
  local body = "{\"sequenceNumber\":" .. sequence .. ",\"screenID\":" .. JsonString(screenID) .. "}"
  QueueHttp("POST", "/api/v1/preset/current/update", body, "Preset " .. ix, function()
    activePreset = ix
  end)
end

local function SetDisplayMode(name, value)
  local body = "{\"value\":" .. value .. ",\"canvasIDs\":" .. CanvasIDArray() .. "}"
  QueueHttp("PUT", "/api/v1/device/displaymode", body, name .. " Mode", function()
    currentMode = name
  end)
end

timeoutTimer.EventHandler = CommandQueue.Timeout
retryTimer.EventHandler = CommandQueue.SendCurrent

local function InitializeControls()
  SetControlString("IPAddress", IPAddress())
  SetControlString("HTTPPort", Port())
  SetControlString("ScreenID", ScreenID())
  SetControlString("CanvasIDs", CanvasIDs())
  SetControlString("LastResponseCode", "")
  SetControlString("LastResponseBody", "")
  currentMode = ""
  for ix = 1, PresetCount() do
    if HasControl("Preset" .. ix .. "Name") and Trim(Control("Preset" .. ix .. "Name").String) == "" then
      SetControlString("Preset" .. ix .. "Name", "Preset " .. ix)
    end
    if HasControl("Preset" .. ix .. "Sequence") and Trim(Control("Preset" .. ix .. "Sequence").String) == "" then
      SetControlString("Preset" .. ix .. "Sequence", tostring(ix - 1))
    end
  end
  ApplyActiveFeedback()
  SetConnected(false)
  SetStatus(Status.Initializing, "Ready")
end

if HasControl("IPAddress") then
  Control("IPAddress").EventHandler = function()
    SetStatus(Status.Initializing, "Ready")
  end
end

if HasControl("HTTPPort") then
  Control("HTTPPort").EventHandler = function()
    SetStatus(Status.Initializing, "Ready")
  end
end

if HasControl("ScreenID") then
  Control("ScreenID").EventHandler = function()
    SetStatus(Status.Initializing, "Ready")
  end
end

if HasControl("CanvasIDs") then
  Control("CanvasIDs").EventHandler = function()
    SetStatus(Status.Initializing, "Ready")
  end
end

if HasControl("NormalMode") then
  Control("NormalMode").EventHandler = function()
    SetDisplayMode("Normal", NormalModeValue())
  end
end

if HasControl("BlackMode") then
  Control("BlackMode").EventHandler = function()
    SetDisplayMode("Black", BlackModeValue())
  end
end

for ix = 1, PresetCount() do
  if HasControl("Preset" .. ix .. "Recall") then
    Control("Preset" .. ix .. "Recall").EventHandler = function()
      RecallPreset(ix)
    end
  end
end

InitializeControls()
