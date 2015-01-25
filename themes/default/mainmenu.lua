local mainmenu = db.getScreen("mainmenu")

mainmenu.onEnter = function()
	if mainmenu.element then
		mainmenu.element.visibility = "Visible"
	end

	-- set input device focus to default widgets...
end

mainmenu.onExit = function()
	if mainmenu.element then
		mainmenu.element.visibility = "Invisible"
	end
end


function selectPlay()
	db.showScreen("songselect")
end

function selectDownload()
	db.showScreen("download")
end

function selectEditor()
	db.showScreen("editor")
end

function selectSettings()
	db.showScreen("options")
end

function selectExit()
	quit()
end
