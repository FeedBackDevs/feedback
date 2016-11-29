-- flow.lua

flow = {}

flow.screens = {}
flow.panels = {}
flow.popups = {}

flow.currentScreen = nil
flow.screenStack = {}
flow.stackDepth = 0

flow.activePopups = {}

db.ui:registerUnhandledInputHandler(function(inputManager, ev)
	-- each popup
	for popup,_ in pairs(flow.activePopups) do
		if popup.onInput then
			if popup:onInput(ev.deref, inputManager) then
				return true
			end
		end
	end

	-- screen has a go
	if flow.currentScreen and flow.currentScreen.onInput then
		if flow.currentScreen:onInput(ev.deref, inputManager) then
			return true
		end
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

function flow.newPopup(name)
	return {
		["__is_popup"] = true,
		["name"] = name,
		["loadUiDesc"] = function(self)
			if not self.template then
				local xml = "screens/" .. self.name .. ".xml"
				self.template = db.loadUiDescriptor(xml)
			end
			return self.template
		end
		["spawn"] = function(self)
			screen = flow.newScreen(self.name)
			screen.ui = self.template.spawn()
			return screen
		end
	}
end

function flow.registerScreen(screen)
	screen:loadUi()
	print("register " .. screen.name)
	flow.screens[screen.name] = screen
end

function flow.registerPanel(screen)
	screen:loadUi()
	print("register panel " .. screen.name)
	flow.panels[screen.name] = screen

	if screen.onInit then
		screen:onInit(arg)
	end
end

function flow.registerPopup(popup)
	popup:loadUiDesc()
	print("register popup " .. popup.name)
	flow.popups[popup.name] = popup
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


function flow.attachPanel(screen, parent_id, panel)
	-- get screen
	if type(screen) == "string" then
		screen = flow.screens[screen]
	else
		if not screen.__is_screen then
			screen = nil
		end
	end
	if not screen then
		logError("Not a screen!")
		return nil
	end

	-- get panel
	if type(panel) == "string" then
		panel = flow.panels[panel]
	else
		if not panel.__is_screen then
			panel = nil
		end
	end
	if not panel then
		logError("Not a panel!")
		return nil
	end

	local attachPoint = screen.ui.findChild(parent_id)
	if attachPoint then
		attachPoint.addChild(panel.ui);
	else
		logError("Screen does not contain item: " .. parent_id)
		return nil
	end

	return panel
end

function flow.showPopup(popup, ...)
	if type(popup) == "string" then
		popup = flow.popups[popup]
	else
		if not popup.__is_popup then
			popup = nil
		end
	end
	if not popup then
		logError("Not a popup!")
		return
	end

	inst = popup.spawn()

	if inst.onInit then
		int:onInit(arg)
	end

	db.ui:addTopLevelWidget(inst.ui)

	if inst.onEnter then
		inst:onEnter()
	end

	return inst
end

function flow.closePopup(popupScreen)
	if not popupScreen.__is_screen then
		logError("Not a screen!")
		return
	end

	if popupScreen.onLeave then
		popupScreen:onLeave()
	end

	db.ui:removeTopLevelWidget(popupScreen.ui)
	popupScreen.ui = nil
end
