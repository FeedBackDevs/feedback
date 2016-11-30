-- themes/default/screens/editor.lua

theme.editor = flow.newScreen("editor")
local m = theme.editor

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
