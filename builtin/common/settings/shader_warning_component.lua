return {
	query_text = "Shaders",
	requires = {
		shaders = false,
	},
	context = "client",
	get_formspec = function(self, avail_w)
		return "label[0,0;" .. fgettext_ne("Shaders are disabled. This may cause visual issues.") .. "]", 0.4
	end,
	on_submit = function(self, fields)
		return false
	end,
}
