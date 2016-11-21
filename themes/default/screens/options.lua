
theme.options = flow.newScreen("options")
local m = theme.options

function m:onInit(...)
end
function m:onEnter()
end
function m:onLeave()
end
function m:onInput(ev, inputManager)
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
