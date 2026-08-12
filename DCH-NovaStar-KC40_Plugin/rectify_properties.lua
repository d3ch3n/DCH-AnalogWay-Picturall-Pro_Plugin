if props.plugin_show_debug ~= nil and props.plugin_show_debug.Value == false and props["Debug Level"] ~= nil then
  props["Debug Level"].IsHidden = true
end
