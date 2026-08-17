-- When priv_bypass is enabled, the client owns the zoom permission: ignore
-- whatever zoom_fov the server sends (usually 0 in survival) and keep zoom
-- forced to 15 so core.localplayer:get_zoom_fov() reports zoom as available.
core.register_on_zoom_fov_changed(function(id, zoom_fov)
	if core.settings:get_bool("priv_bypass") then
		return 15
	end
	return nil
end)
