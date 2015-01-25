local editor = db.getScreen("editor")

editor.onEnter = function()
	if editor.element then
		editor.element.visibility = "Visible"
	end

	-- set input device focus to default widgets...
end

editor.onExit = function()
	if editor.element then
		editor.element.visibility = "Invisible"
	end
end
