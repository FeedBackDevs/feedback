-- Default theme --

print "Loaded 'Default' theme..."

function begin()
	ui:find("theme").visibility = "Visible"

	-- register input function to handle global key presses
	db.setInputHandler(function(ev, inputManager)
--		print("Got: " .. ev.deviceID)
--		print("Got: " .. ev.sourceID)

		-- handle global 'back' button
		if ev.ev == "ButtonDown" and (ev.buttonID == 27 or ev.buttonID == 8) then
			db.showPrevScreen()
			return true
		end
	end)

	db.showScreen("mainmenu", true)
end
