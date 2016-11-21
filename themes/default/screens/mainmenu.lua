
theme.mainmenu = flow.newScreen("mainmenu")
local m = theme.mainmenu

function m:onInit(...)
end
function m:onEnter()
end
function m:onLeave()
end
function m:onInput(ev, inputManager)
end

function m:selectPlay()
	flow.pushScreen("songselect")
end

function m:selectDownload()
	flow.pushScreen("download")
end

function m:selectEditor()
	flow.pushScreen("editor")
	db.startEditor()
end

function m:selectSettings()
	flow.pushScreen("options")
end

function m:selectExit()
	db.quit()
end

return m
