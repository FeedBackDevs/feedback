-- themes/default/screens/performance.lua

theme.performance = flow.newScreen("performance")
local m = theme.performance

m.paused = false

function m:onInit(...)
end
function m:onEnter()
end
function m:onLeave()
end
function m:onInput(ev, inputManager)
end

function m:pause(pause)
	db.pausePerformance(pause)
	self.paused = pause

	if pause then
		ui:find("ingameoptions").visibility = "Visible"
	else
		ui:find("ingameoptions").visibility = "Invisible"
	end
end

function m:exit()
	db.endPerformance()

	flow.popScreen()
end

return m
