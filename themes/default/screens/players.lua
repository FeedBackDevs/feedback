-- themes/default/screens/players.lua

theme.players = flow.newScreen("players")
local m = theme.players

function m:onInit(...)
end
function m:onEnter()
end
function m:onLeave()
end
function m:onInput(ev, inputManager)
	if ev.ev == "ButtonDown" and
	  ((ev.device == "Keyboard" and (ev.buttonID == 13 or ev.buttonID == 32)) or -- enter or space
	  (ev.device == "Gamepad" and ev.buttonID == 8)) then -- start
		-- pass UI to the theme, supplying the input source that pressed start
		if not db.inputInUse(ev.pSource) then
			db.createPlayer(ev.pSource)
		end
		return true
	end
end

return m
