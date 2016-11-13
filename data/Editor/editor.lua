editor = db.getScreen("editor")

editor.menu = {}
editor.mainmenu = {}
editor.songs = {}
editor.chartsettings = {}

function editor.onEnter()
	if editor.element then
		editor.element.visibility = "Visible"
	end

	editor.menu.ui = editor.element:findChild("menu");
	editor.songs.ui = editor.element:findChild("picksong");

	editor.oldInputHandler = db.setInputHandler(editor.inputHandler)

	-- set input device focus to default widgets...
end

function editor.onExit()
	db.setInputHandler(editor.oldInputHandler)

	if editor.element then
		editor.element.visibility = "Invisible"
	end
end

function editor.inputHandler(ev, inputManager)

	if ev.device == "Keyboard" then
		-- escape key
		if ev.ev == "ButtonDown" and ev.buttonID == 27 then
			if editor.menu.ui.visibility == "Gone" then
				editor.menu.ui.visibility = "Visible"
--				editor.showmenu(editor.mainmenu) -- doesn't work! :(
			else
				editor.menu.ui.visibility = "Gone"
			end
			return true
		end
	end

	print(ev.sourceID .. " - " .. ev.device .. "(" .. ev.deviceID .. ") - " .. ev.ev .. ": " .. ev.buttonID)

	return true
end

function editor.showmenu(menu)
	editor.currentmenu = menu
	editor.menu.ui.list = ArrayAdapter(menu.items, menu.get, menu.update)
	editor.menu.ui.visibility = "Visible"
end

function editor.menu.select(w, i)
	if editor.currentmenu.select then
		editor.currentmenu.select(w, i)
	end
end
function editor.menu.click(w, i)
	if editor.currentmenu.click(w, i) then
		editor.menu.ui.visibility = "Gone"
	end
end

-- main menu

function editor.mainmenu.get(item, userdata)
	local l = Label()
	l.textColour = Vector.white
	l.text = item
	return l
end
function editor.mainmenu.update(item, layout, userdata)
	layout.text = item
	print("update layout!")
end
editor.mainmenu.items = ArrayAdapter({ "New Chart", "Open Chart", "Save Chart", "Chart Settings", "Show Help", "Exit" }, editor.mainmenu.get, editor.mainmenu.update)

function editor.mainmenu.select(w, i)
end

function editor.mainmenu.click(w, i)
	if i == 1 then
		-- choose audio o file for new song...
	elseif i == 2 then
		-- open song from songs folder
		editor.songs.ui.visibility = "Visible"
	elseif i == 3 then
		-- save
	elseif i == 4 then
		-- show chart settings
	elseif i == 5 then
		-- show help
	elseif i == 6 then
		db.showPrevScreen()
	end

	if i >= 1 and i <= 6 then
		editor.menu.ui.visibility = "Gone"
		return true
	end
	return false
end

-- songs

function editor.songs.get(item, userdata)
	local l = Label()
	l.textColour = Vector.white
	l.text = item
	return l
end
function editor.songs.update(item, layout, userdata)
	layout.text = item
	print("update layout!")
end
editor.songs.items = songs

function editor.songs.select(w, i)
end

function editor.songs.click(w, i)
	editor.songs.ui.visibility = "Gone"

	local song = songs[i]

	print (i)

	return true
end

-- chart settings

editor.chartsettings.items = { "Song Name: ", "Artist Name: ", "Charter Name: ", "Year: ", "Difficulty: ", "Genre: "  }
function editor.chartsettings.get(item, userdata)
	local l = Label()
	l.textColour = Vector.white
	l.text = item
	return l
end
function editor.chartsettings.update(item, layout, userdata)
	layout.text = item
	print("update layout!")
end

function editor.chartsettings.click(w, i)
	if i == 1 then
	elseif i == 2 then
	elseif i == 3 then
	elseif i == 4 then
	elseif i == 5 then
	elseif i == 6 then
	end

	if i >= 1 and i <= 6 then
		return true
	end
	return false
end
