-- themes/default/screens/options.lua

theme.options = flow.newScreen("options")
local m = theme.options

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

	if ev.ev == "ButtonDown" and theme.isMenuDevice(ev.pSource) then
		if (ev.device == "Keyboard" and ev.buttonID == 27) or
		   (ev.device == "Gamepad" and ev.buttonID == 1) then
			self:exit()
			return true
		end
	end
end

function m:theme()
end
function m:input()
end
function m:latency()
end

function m:exit()
	flow.popScreen()
end

return m
