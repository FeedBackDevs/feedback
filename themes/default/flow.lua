-- themes/default/flow.lua

local function loadScreen(filename)
	local screen = dofile(db.themePath("screens/" .. filename .. ".lua"))
	flow.registerScreen(screen)
end

local function loadPopup(filename)
	local popup = dofile(db.themePath("screens/popups/" .. filename .. ".lua"))
	flow.registerPopup(popup)
end

local function loadPanel(filename)
	local panel = dofile(db.themePath("screens/" .. filename .. ".lua"))
	flow.registerPanel(panel)
end

local function loadListItem(filename, list)
	list.itemDescriptor = db.loadUiDescriptor("screens/items/" .. filename .. ".xml")
end

loadListItem("player", db.playerlist)
loadListItem("song", db.library.songlist)

loadPanel("players")

loadScreen("songselect")
loadScreen("boot")
loadScreen("mainmenu")
loadScreen("editor")
loadScreen("options")
loadScreen("download")
loadScreen("performance")

loadPopup("playeropts")

-- enter main menu
print("show boot screen...")
flow.pushScreen("boot")
