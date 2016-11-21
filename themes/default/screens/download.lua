
theme.download = flow.newScreen("download")
local m = theme.download

function m:onInit(...)
end
function m:onEnter()
end
function m:onLeave()
end
function m:onInput(ev, inputManager)
end

function m:exit()
	flow.popScreen()
end

return m
