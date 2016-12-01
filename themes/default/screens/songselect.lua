-- themes/default/screens/songselect.lua

theme.songselect = flow.newScreen("songselect")
local m = theme.songselect

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
			self:back()
			return true
		end
	end
end


function m:selectSong(index)
end
function m:playSong(index)

	if index ~= 0 then
		local song = db.library.songlist:get(index)
		db.startPerformance(song)

		flow.pushScreen("performance")
	end
end
function m:back()
	flow.popScreen()
end

return m
