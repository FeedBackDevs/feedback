-- themes/default/screens/mainmenu.lua

theme.mainmenu = flow.newScreen("mainmenu")
local m = theme.mainmenu

function m:onInit(...)
end
function m:onEnter()
	self.panel = flow.attachPanel(self, "playerpanel", "players")
end
function m:onLeave()
	flow.detachPanel(self.panel)
end
function m:onInput(ev, inputManager)
	if self.panel:onInput(ev, inputManager) then
		return true
	end

	-- ...
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
