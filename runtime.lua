-- Analog Way Picturall Pro external control
--
-- Protocol source notes:
-- * Analog Way describes Picturall external control as Ethernet TCP/IP with a
--   comprehensive text based protocol.
-- * The Bitfocus Companion Analog Way Picturall module documents the default
--   control TCP port as 11000 and recommends using Picturall Commander logging
--   or Companion Learn to obtain the exact "set ..." command strings.
-- * Picturall Server 3.5.x supports cue stacks/playbacks. This plugin sends
--   operator-configured textual commands and does not assume undocumented
--   commands for the target show file.

local DefaultPort = 11000
local DefaultTimeout = 5
local DefaultPollInterval = 10

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
local pollTimer = Timer.New()
local retryTimer = Timer.New()
local queue = {}
local currentCommand = nil
local rxBuffer = ""
local socketConnected = false
local updatingFeedback = false
local lastRequestedPreset = nil
local activeCueStack = ""
local activePlayback = ""
local activeCue = ""
local playbackState = ""

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

local function PropIsYes(name, default)
  local value = tostring(GetProperty(name, default and "Yes" or "No"))
  return value == "Yes" or value == "true" or value == "1"
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
  socketConnected = state
  if HasControl("ConnectionActive") then
    Control("ConnectionActive").Boolean = state
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

local function Port()
  local value = DefaultPort
  if HasControl("TCPPort") and Control("TCPPort").String ~= nil and tonumber(Control("TCPPort").String) ~= nil then
    value = math.floor(tonumber(Control("TCPPort").String))
  else
    value = tonumber(GetProperty("TCP Port", DefaultPort)) or DefaultPort
  end
  if value < 1 or value > 65535 then
    value = DefaultPort
  end
  return value
end

local function IPAddress()
  if HasControl("IPAddress") and Control("IPAddress").String ~= nil and Control("IPAddress").String ~= "" then
    return Control("IPAddress").String
  end
  return tostring(GetProperty("IP Address", ""))
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

local function PollInterval()
  return tonumber(GetProperty("Poll Interval", DefaultPollInterval)) or DefaultPollInterval
end

local function DefaultPlayback()
  local value = math.floor(tonumber(GetProperty("Default Playback", 1)) or 1)
  if value < 1 then
    return 1
  elseif value > 8 then
    return 8
  end
  return value
end

local function LineEnding()
  local value = tostring(GetProperty("Line Ending", "LF"))
  if value == "CRLF" then
    return "\r\n"
  elseif value == "CR" then
    return "\r"
  elseif value == "None" then
    return ""
  end
  return "\n"
end

local function Trim(value)
  value = tostring(value or "")
  value = string.gsub(value, "^%s+", "")
  value = string.gsub(value, "%s+$", "")
  return value
end

local function PresetName(ix)
  local configured = Trim(HasControl("Preset" .. ix .. "Name") and Control("Preset" .. ix .. "Name").String or "")
  if configured ~= "" then
    return configured
  end
  return "Preset " .. ix
end

local function PresetPlayback(ix)
  local configured = Trim(HasControl("Preset" .. ix .. "Playback") and Control("Preset" .. ix .. "Playback").String or "")
  local numeric = tonumber(configured)
  if numeric ~= nil then
    return tostring(math.floor(numeric))
  end
  return tostring(DefaultPlayback())
end

local function PresetCueStack(ix)
  return Trim(HasControl("Preset" .. ix .. "CueStack") and Control("Preset" .. ix .. "CueStack").String or "")
end

local function PresetCommand(ix)
  return Trim(HasControl("Preset" .. ix .. "Command") and Control("Preset" .. ix .. "Command").String or "")
end

local function PlaybackGoCommand(ix)
  return Trim(HasControl("Playback" .. ix .. "GoCommand") and Control("Playback" .. ix .. "GoCommand").String or "")
end

local function DefaultPlaybackGoCommand(ix)
  return "set stack" .. ix .. " control command=1"
end

local function ApplyPresetActiveFeedback()
  updatingFeedback = true
  for ix = 1, PresetCount() do
    local cueStack = PresetCueStack(ix)
    local playback = PresetPlayback(ix)
    local matchedByFeedback = activeCueStack ~= "" and cueStack ~= "" and activeCueStack == cueStack and activePlayback == playback
    local pending = lastRequestedPreset == ix and activeCueStack == ""
    SetControlBoolean("Preset" .. ix .. "Active", matchedByFeedback or pending)
  end
  for ix = 1, PlaybackCount() do
    SetControlBoolean("Playback" .. ix .. "Active", activePlayback == tostring(ix))
  end
  updatingFeedback = false
end

local function UpdatePlaybackFeedback(playback, cueStack, cue, state)
  if playback ~= nil and playback ~= "" then
    activePlayback = tostring(playback)
    SetControlString("ActivePlayback", activePlayback)
  end
  if cueStack ~= nil and cueStack ~= "" then
    activeCueStack = tostring(cueStack)
    SetControlString("ActiveCueStack", activeCueStack)
  end
  if cue ~= nil and cue ~= "" then
    activeCue = tostring(cue)
    SetControlString("ActiveCue", activeCue)
  end
  if state ~= nil and state ~= "" then
    playbackState = tostring(state)
    SetControlString("PlaybackState", playbackState)
  end
  ApplyPresetActiveFeedback()
end

local function ParseFeedbackLine(line)
  local text = Trim(line)
  if text == "" then
    return
  end
  DebugPrint("Rx", "RX: " .. text)
  SetControlString("CommandStatus", text)

  local version = string.match(text, "[Vv]ersion[%s:=]+([%w%._%-]+)")
  if version ~= nil then
    SetControlString("ServerVersion", version)
  end

  local playback, cueStack = string.match(text, "[Pp]layback%s*(%d+).-[Cc]ue[Ss]tack[%s:=]+([%w%._%-]+)")
  if playback == nil then
    playback, cueStack = string.match(text, "playback(%d+)_cuestack[%s:=]+([%w%._%-]+)")
  end
  if playback == nil then
    playback, cueStack = string.match(text, "playback(%d+)_questack[%s:=]+([%w%._%-]+)")
  end
  local cue = string.match(text, "[Cc]ue[%s:=]+([%d%.]+)")
  local state = string.match(text, "[Ss]tate[%s:=]+(.+)")

  if playback ~= nil or cueStack ~= nil or cue ~= nil or state ~= nil then
    UpdatePlaybackFeedback(playback, cueStack, cue, state)
  end
end

local function ExtractLines(data)
  rxBuffer = rxBuffer .. data
  local lines = {}
  while true do
    local lf = string.find(rxBuffer, "\n", 1, true)
    if lf == nil then
      break
    end
    table.insert(lines, Trim(string.sub(rxBuffer, 1, lf - 1)))
    rxBuffer = string.sub(rxBuffer, lf + 1)
  end
  if #rxBuffer > 0 and string.find(rxBuffer, "\r", 1, true) ~= nil then
    local cr = string.find(rxBuffer, "\r", 1, true)
    table.insert(lines, Trim(string.sub(rxBuffer, 1, cr - 1)))
    rxBuffer = string.sub(rxBuffer, cr + 1)
  end
  return lines
end

CommandQueue = {}

function CommandQueue.Add(item)
  table.insert(queue, item)
  CommandQueue.Process()
end

function CommandQueue.Process()
  if currentCommand ~= nil or socket == nil or not socketConnected then
    return
  end
  currentCommand = table.remove(queue, 1)
  if currentCommand ~= nil then
    CommandQueue.SendCurrent()
  end
end

function CommandQueue.SendCurrent()
  if currentCommand == nil or socket == nil or not socketConnected then
    return
  end
  DebugPrint("Tx", "TX: " .. currentCommand.command)
  socket:Write(currentCommand.command .. LineEnding())
  timeoutTimer:Start(ResponseTimeout())
end

function CommandQueue.Timeout()
  if currentCommand == nil then
    return
  end
  if currentCommand.retries < RetryCount() then
    currentCommand.retries = currentCommand.retries + 1
    CommandQueue.SendCurrent()
  else
    DebugPrint("Function Calls", "No response for command: " .. currentCommand.command)
    SetControlString("CommandStatus", "No response: " .. currentCommand.label)
    currentCommand = nil
    SetStatus(Status.Compromised, "Command sent, no feedback")
    CommandQueue.Process()
  end
end

function CommandQueue.Clear()
  queue = {}
  currentCommand = nil
  timeoutTimer:Stop()
end

local function QueueCommand(command, label)
  command = Trim(command)
  if command == "" then
    SetControlString("CommandStatus", "Missing command")
    SetStatus(Status.Compromised, "Missing preset command")
    return
  end
  CommandQueue.Add({command = command, label = label or command, retries = 0})
end

local function PollFeedback()
  -- Picturall's public integration guidance recommends learning exact command
  -- names from Commander logs. Keep polling conservative and rely on passive
  -- status messages unless the site-specific show exposes query commands.
  ApplyPresetActiveFeedback()
end

local function CloseSocket()
  CommandQueue.Clear()
  pollTimer:Stop()
  if socket ~= nil then
    socket:Disconnect()
  end
  SetConnected(false)
  SetStatus(Status.NotPresent, "Offline")
end

local function ScheduleRetry(reason)
  pollTimer:Stop()
  SetConnected(false)
  if reason ~= nil and reason ~= "" then
    DebugPrint("Function Calls", "Connection closed: " .. tostring(reason))
  end
  retryTimer:Start(RetryDelay())
  SetStatus(Status.Compromised, "Reconnecting")
end

local function OpenSocket()
  local ip = IPAddress()
  if ip == "" then
    SetConnected(false)
    SetStatus(Status.Missing, "Missing IP Address")
    retryTimer:Stop()
    return
  end

  retryTimer:Stop()
  CommandQueue.Clear()
  pollTimer:Stop()

  if socket == nil then
    socket = TcpSocket.New()
    socket.EventHandler = function(sock, event, err)
      if event == TcpSocket.Events.Connected then
        DebugPrint("Function Calls", "Connected")
        SetConnected(true)
        SetStatus(Status.OK, "Connected")
        PollFeedback()
        if PropIsYes("Enable Feedback Polling", true) then
          pollTimer:Start(PollInterval())
        end
      elseif event == TcpSocket.Events.Data then
        local data = sock:Read(sock.BufferLength)
        local lines = ExtractLines(data)
        for _, line in ipairs(lines) do
          ParseFeedbackLine(line)
        end
        if currentCommand ~= nil and #lines > 0 then
          timeoutTimer:Stop()
          currentCommand = nil
          SetStatus(Status.OK, "OK")
          CommandQueue.Process()
        end
      elseif event == TcpSocket.Events.Closed or event == TcpSocket.Events.Error or event == TcpSocket.Events.Timeout then
        ScheduleRetry(err or "Connection Error")
      end
    end
  end

  SetStatus(Status.Compromised, "Connecting to " .. ip .. ":" .. Port())
  DebugPrint("Function Calls", "Connecting to " .. ip .. ":" .. Port())
  socket:Connect(ip, Port())
end

local function InitializeControls()
  SetControlString("IPAddress", IPAddress())
  SetControlString("TCPPort", Port())
  SetControlString("ServerVersion", "")
  SetControlString("ActivePlayback", tostring(DefaultPlayback()))
  SetControlString("ActiveCueStack", "")
  SetControlString("ActiveCue", "")
  SetControlString("PlaybackState", "")
  SetControlString("CommandStatus", "")
  for ix = 1, PresetCount() do
    if HasControl("Preset" .. ix .. "Name") and Trim(Control("Preset" .. ix .. "Name").String) == "" then
      SetControlString("Preset" .. ix .. "Name", "Preset " .. ix)
    end
    if HasControl("Preset" .. ix .. "Playback") and Trim(Control("Preset" .. ix .. "Playback").String) == "" then
      SetControlString("Preset" .. ix .. "Playback", tostring(DefaultPlayback()))
    end
  end
  for ix = 1, PlaybackCount() do
    if HasControl("Playback" .. ix .. "GoCommand") and Trim(Control("Playback" .. ix .. "GoCommand").String) == "" then
      SetControlString("Playback" .. ix .. "GoCommand", DefaultPlaybackGoCommand(ix))
    end
    SetControlBoolean("Playback" .. ix .. "Active", ix == DefaultPlayback())
  end
  SetConnected(false)
  SetStatus(Status.Initializing, "Initializing")
  OpenSocket()
end

local function RecallPreset(ix)
  local command = PresetCommand(ix)
  if command == "" then
    SetControlString("CommandStatus", "Preset " .. ix .. " command is empty")
    SetStatus(Status.Compromised, "Missing preset command")
    return
  end
  lastRequestedPreset = ix
  activePlayback = PresetPlayback(ix)
  SetControlString("ActivePlayback", activePlayback)
  SetControlString("CommandStatus", "Requesting " .. PresetName(ix))
  ApplyPresetActiveFeedback()
  DebugPrint("Function Calls", "Cue stack requested: " .. PresetName(ix))
  QueueCommand(command, PresetName(ix))
end

local function PlaybackGo(ix)
  local command = PlaybackGoCommand(ix)
  if command == "" then
    SetControlString("CommandStatus", "Playback " .. ix .. " Go command is empty")
    SetStatus(Status.Compromised, "Missing playback command")
    return
  end
  activePlayback = tostring(ix)
  SetControlString("ActivePlayback", activePlayback)
  SetControlString("CommandStatus", "Playback " .. ix .. " Go")
  ApplyPresetActiveFeedback()
  DebugPrint("Function Calls", "Playback Go requested: " .. ix)
  QueueCommand(command, "Playback " .. ix .. " Go")
end

timeoutTimer.EventHandler = CommandQueue.Timeout
pollTimer.EventHandler = PollFeedback
retryTimer.EventHandler = OpenSocket

if HasControl("IPAddress") then
  Control("IPAddress").EventHandler = function()
    CloseSocket()
    OpenSocket()
  end
end

if HasControl("TCPPort") then
  Control("TCPPort").EventHandler = function()
    CloseSocket()
    OpenSocket()
  end
end

if HasControl("PollFeedback") then
  Control("PollFeedback").EventHandler = PollFeedback
end

for ix = 1, PlaybackCount() do
  if HasControl("Playback" .. ix .. "Go") then
    Control("Playback" .. ix .. "Go").EventHandler = function()
      PlaybackGo(ix)
    end
  end
end

for ix = 1, PresetCount() do
  if HasControl("Preset" .. ix .. "Go") then
    Control("Preset" .. ix .. "Go").EventHandler = function()
      RecallPreset(ix)
    end
  end
  if HasControl("Preset" .. ix .. "CueStack") then
    Control("Preset" .. ix .. "CueStack").EventHandler = ApplyPresetActiveFeedback
  end
  if HasControl("Preset" .. ix .. "Playback") then
    Control("Preset" .. ix .. "Playback").EventHandler = ApplyPresetActiveFeedback
  end
end

InitializeControls()
