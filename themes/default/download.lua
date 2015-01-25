local download = db.getScreen("download")

download.onEnter = function()
	if download.element then
		download.element.visibility = "Visible"
	end

	-- set input device focus to default widgets...
end

download.onExit = function()
	if download.element then
		download.element.visibility = "Invisible"
	end
end
