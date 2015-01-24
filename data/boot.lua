-- FeedBack bootup script --

-- This script will execute on creation of the boot.xml UI
print "Boot script..."

db = {}
db.state = {}

local state = db.state


-- the db api...

db.currentScreen = nil
state.screens = {}
state.prevScreens = {}
state.prevDepth = 0

state.attrHandlers = {}

function db.setInputHandler(handler)
	local old = state.inputHandler
	state.inputHandler = handler
	return old;
end

function db.registerAttribute(attr_name, handler)
	state.attrHandlers[attr_name] = handler
end

function db.getScreen(name)
	if not state.screens[name] then
		state.screens[name] = {}

		-- set screen defaults
		--...
	end
	return state.screens[name]
end

function db.showScreen(screen, noPrev)
	if type(screen) == "string" then
		screen = state.screens[screen]
	end
	if not screen then
		warn(2, "Can't show screen '" .. name .. "', screen does not exist!")
		return
	end

	if db.currentScreen and db.currentScreen.onExit then
		db.currentScreen.onExit()
	end

	local prev = db.currentScreen
	if not noPrev then
		db.pushPrevScreen(prev)
	end

	db.currentScreen = screen

	if screen.onEnter then
		screen.onEnter()
	end

	return prev
end

function db.pushPrevScreen(screen)
	if type(screen) == "string" then
		screen = state.screens[screen]
	end
	if not screen then
		return state.prevDepth
	end

	state.prevDepth = state.prevDepth + 1
	state.prevScreens[state.prevDepth] = screen
	return state.prevDepth
end

function db.popPrevScreen()
	local prev = nil
	if state.prevDepth > 0 then
		prev = state.prevScreens[state.prevDepth]
		state.prevScreens[state.prevDepth] = nil -- allow garbage collection of screens on prev stack
		state.prevDepth = state.prevDepth - 1
	end
	return prev
end

function db.getPrevScreen()
	if state.prevDepth > 0 then
		return state.prevScreens[state.prevDepth]
	end
	return nil
end

function db.clearPrevScreens()
	while db.popPrevScreen() ~= nil do
	end
end

function db.showPrevScreen()
	local prev = db.popPrevScreen()
	if prev ~= nil then
		db.showScreen(prev, true)
	end
end


-- to run at startup...

ui:registerUnhandledInputHandler(function(inputManager, ev)
	if db.state.inputHandler and db.state.inputHandler(ev.deref, inputManager) then
		return true
	end

	print("Unhandled input event: " .. ev.deref.ev .. " - " .. ev.deref.buttonID)

	return false
end)

ui:registerUnknownPropertyHandler(function(element, attribute, value)
	local handler = db.state.attrHandlers[attribute]
	if handler then
		handler(element, attribute, value)
	else
		element.data[attribute] = value
	end
end)

db.registerAttribute("screen", function(element, attribute, value)
	local screen = db.getScreen(value)

	screen.element = element

	element.id = value
	element.visibility = "Invisible"
end)


-- UI bootup

local boot_screen = db.getScreen("boot_screen")

boot_screen.onEnter = function()
	if boot_screen.element then
		boot_screen.element.visibility = "Visible"
	end
end

boot_screen.onExit = function()
	if boot_screen.element then
		boot_screen.element.visibility = "Invisible"
	end
end

db.currentScreen = boot_screen

-- load boox.xml, add it to the root node.


-- UI event handlers

function bootScreenClick()
	begin()
end
