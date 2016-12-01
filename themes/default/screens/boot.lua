-- themes/default/screens/boot.lua

theme.boot = flow.newScreen("boot")
local m = theme.boot

function m:onInit(...)
end
function m:onEnter()
end
function m:onLeave()
end
function m:onInput(ev, inputManager)
	if ev.ev == "ButtonDown" and
	  (ev.device == "Keyboard" and (ev.buttonID == 13 or ev.buttonID == 32)) or -- enter or space
	  (ev.device == "Gamepad" and ev.buttonID == 8) then -- start
		-- pass UI to the theme, supplying the input source that pressed start
		db.createPlayer(ev.pSource)

		theme.masterDevice = ev.device
		theme.masterDeviceId = ev.deviceID

		self:start()
		return true
	end
end

function m:start()
	flow.changeScreen("mainmenu")
end

return m
