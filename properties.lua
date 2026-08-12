table.insert(props, {Name = "IP Address", Type = "string", Value = ""})
table.insert(props, {Name = "TCP Port", Type = "integer", Min = 1, Max = 65535, Value = 11000})
table.insert(props, {Name = "Preset Count", Type = "integer", Min = 1, Max = 24, Value = 5})
table.insert(props, {Name = "Playback Count", Type = "integer", Min = 1, Max = 8, Value = 8})
table.insert(props, {Name = "Default Playback", Type = "integer", Min = 1, Max = 8, Value = 1})
table.insert(props, {Name = "Poll Interval", Type = "integer", Min = 1, Max = 300, Value = 10})
table.insert(props, {Name = "Response Timeout", Type = "integer", Min = 1, Max = 60, Value = 5})
table.insert(props, {Name = "Retry Count", Type = "integer", Min = 0, Max = 10, Value = 1})
table.insert(props, {Name = "Retry Delay", Type = "integer", Min = 1, Max = 300, Value = 5})
table.insert(props, {
  Name = "Line Ending",
  Type = "enum",
  Choices = {"LF", "CRLF", "CR", "None"},
  Value = "LF"
})
table.insert(props, {Name = "Enable Feedback Polling", Type = "enum", Choices = {"Yes", "No"}, Value = "Yes"})
table.insert(props, {
  Name = "Debug Level",
  Type = "enum",
  Choices = {"None", "Tx/Rx", "Function Calls", "All"},
  Value = "None"
})
