-- themes/default/screens/download.lua

theme.download = flow.newScreen("download")
local m = theme.download

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

function m:exit()
	flow.popScreen()
end

return m
