
theme.mainmenu = flow.newScreen("mainmenu")
local m = theme.mainmenu

function m:onInit(...)
	self.panel = flow.attachPanel(self, "ui_id", "name")
end
function m:onEnter()
end
function m:onLeave()
end
function m:onInput(ev, inputManager)
	if self.panel.onInout(ev, inputManager) then
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
