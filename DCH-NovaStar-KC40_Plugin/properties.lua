table.insert(props, {Name = "IP Address", Type = "string", Value = ""})
table.insert(props, {Name = "HTTP Port", Type = "integer", Min = 1, Max = 65535, Value = 8001})
table.insert(props, {Name = "Screen ID", Type = "string", Value = ""})
table.insert(props, {Name = "Canvas IDs", Type = "string", Value = "1"})
table.insert(props, {Name = "Preset Count", Type = "integer", Min = 1, Max = 32, Value = 8})
table.insert(props, {Name = "Normal Mode Value", Type = "integer", Min = 0, Max = 255, Value = 0})
table.insert(props, {Name = "Black Mode Value", Type = "integer", Min = 0, Max = 255, Value = 1})
table.insert(props, {Name = "Response Timeout", Type = "integer", Min = 1, Max = 60, Value = 5})
table.insert(props, {Name = "Retry Count", Type = "integer", Min = 0, Max = 10, Value = 1})
table.insert(props, {Name = "Retry Delay", Type = "integer", Min = 1, Max = 300, Value = 5})
table.insert(props, {
  Name = "Debug Level",
  Type = "enum",
  Choices = {"None", "Tx/Rx", "Function Calls", "All"},
  Value = "None"
})
