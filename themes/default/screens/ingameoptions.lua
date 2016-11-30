-- themes/default/screens/ingameoptions.lua

function resumegame()
	db.getScreen("performance").pause(false)
end

function quitsong()
	db.getScreen("performance").quit()
end

