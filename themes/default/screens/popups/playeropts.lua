-- themes/default/screens/options.lua

theme.playeropts = flow.newPopup("playeropts")
local m = theme.playeropts

function m:onNewInstance()
	return {
		onInit = function(self, player)
			self.player = player
		end,
		onEnter = function(self)
		end,
		onLeave = function(self)
		end,
		onInput = function(self, ev, inputManager)
		end,

		close = function(self)
			flow.closePopup(self)
		end
	}
end

return m
