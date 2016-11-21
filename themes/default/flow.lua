-- default/flow.lua

local function loadScreen(filename)
	local screen = dofile(db.themePath("screens/" .. filename .. ".lua"))
	flow.registerScreen(screen)
end

loadScreen("songselect")
loadScreen("boot")
loadScreen("mainmenu")
loadScreen("editor")
loadScreen("options")
loadScreen("download")
loadScreen("performance")

-- enter main menu
print("show boot screen...")
flow.pushScreen("boot")
