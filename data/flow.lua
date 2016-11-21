-- flow.lua

flow = {}

flow.screens = {}

flow.currentScreen = nil
flow.screenStack = {}
flow.stackDepth = 0

db.ui:registerUnhandledInputHandler(function(inputManager, ev)
	if flow.currentScreen and flow.currentScreen.onInput then
		flow.currentScreen:onInput(ev.deref, inputManager)
		return true
	end

	print(ev.deref.sourceID .. " - " .. ev.deref.device .. "(" .. ev.deref.deviceID .. ") - " .. ev.deref.ev .. ": " .. ev.deref.buttonID)

	-- should return false here, and let the onInput function above digest the message??
	return true
end)


function flow.newScreen(name)
	return {
		["__is_screen"] = true,
		["name"] = name,
		["loadUi"] = function(self)
			if not self.ui then
				local xml = "screens/" .. self.name .. ".xml"
				self.ui = db.loadUi(xml)
			end
			return self.ui
		end
	}
end

function flow.registerScreen(screen)
	screen:loadUi()
	print("register " .. screen.name)
	flow.screens[screen.name] = screen
end

function flow.getScreen(name)
	return flow.screens[name]
end

local function doPushScreen(push, screen, ...)
	-- leave the current screen
	if flow.stackDepth > 0 then
		local exitScreen = flow.screenStack[flow.stackDepth]
		if exitScreen.onLeave then
			exitScreen:onLeave()
		end
		db.ui:removeTopLevelWidget(exitScreen.ui)
	end

	if push then
		flow.stackDepth = flow.stackDepth + 1
	end
	local enterScreen
	if type(screen) == "string" then
		enterScreen = flow.screens[screen]
	else
		if screen.__is_screen then
			enterScreen = screen
		end
	end

	-- check the new screen is a screen
	if not enterScreen then
		if type(screen) == "string" then
			print("No screen '" .. screen .. "'!")
		else
			print("Not a screen!")
		end
		return;
	end

	flow.screenStack[flow.stackDepth] = enterScreen
	flow.currentScreen = enterScreen

	-- make new screen current
	if enterScreen.onInit then
		enterScreen:onInit(arg)
	end

	db.ui:addTopLevelWidget(enterScreen.ui)

	if enterScreen.onEnter then
		enterScreen:onEnter()
	end
end

function flow.pushScreen(screen, ...)
	doPushScreen(true, screen, arg)
end

function flow.changeScreen(screen, ...)
	doPushScreen(flow.stackDepth == 0, screen, arg)
end

function flow.popScreen()
	assert(flow.stackDepth > 0)

	local exitScreen = flow.screenStack[flow.stackDepth]
	if exitScreen.onLeave then
		exitScreen:onLeave()
	end
	db.ui:removeTopLevelWidget(exitScreen.ui)

	flow.stackDepth = flow.stackDepth - 1
	local enterScreen = flow.screenStack[flow.stackDepth]
	flow.currentScreen = enterScreen

	db.ui:addTopLevelWidget(enterScreen.ui)
	if enterScreen.onEnter then
		enterScreen:onEnter()
	end
end

function flow.clearScreens()
	local first = true
	while flow.stackDepth > 0 do
		local exitScreen = flow.screenStack[flow.stackDepth]
		if exitScreen.onLeave then
			exitScreen:onLeave()
		end
		if first then
			db.ui:removeTopLevelWidget(exitScreen.ui)
			first = false
		end
		flow.stackDepth = flow.stackDepth - 1
	end
	flow.currentScreen = nil
end
