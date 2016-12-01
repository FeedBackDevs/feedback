-- themes/default/flow.lua

local function loadScreen(filename)
	local screen = dofile(db.themePath("screens/" .. filename .. ".lua"))
	flow.registerScreen(screen)
end

local function loadPanel(filename)
	local panel = dofile(db.themePath("screens/" .. filename .. ".lua"))
	flow.registerPanel(panel)
end

local function loadListItem(filename, list)
	list.itemDescriptor = db.loadUiDescriptor("screens/items/" .. filename .. ".xml")
end

loadScreen("songselect")
loadScreen("boot")
loadScreen("mainmenu")
loadScreen("editor")
loadScreen("options")
loadScreen("download")
loadScreen("performance")

loadPanel("players")

loadListItem("player", db.playerlist)

-- enter main menu
print("show boot screen...")
flow.pushScreen("boot")
