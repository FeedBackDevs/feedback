local performance = db.getScreen("performance")

function performance.onEnter()
	if performance.element then
		performance.element.visibility = "Visible"
	end

	-- set ingame options to defaults...
	ui:find("ingameoptions").visibility = "Invisible"

	-- register input function to handle global key presses
	performance.prevInputHandler = db.setInputHandler(function(ev, inputManager)
		print("ingame handler")
		if ev.ev == "ButtonDown" and (ev.buttonID == 27 or ev.buttonID == 8) then
			performance.pause(not performance.paused)
			return true
		end
		return performance.prevInputHandler(ev, inputManager)
	end)

	-- set input device focus to default widgets...
end

function performance.onExit()
	if performance.element then
		performance.element.visibility = "Invisible"
	end

	db.setInputHandler(performance.prevInputHandler)

	endPerformance()
end

function performance.pause(pause)
	-- pause the game
	pausePerformance(pause)

	if pause then
		ui:find("ingameoptions").visibility = "Visible"
	else
		ui:find("ingameoptions").visibility = "Invisible"
	end

	performance.paused = pause
end

function performance.quit()
	db.showPrevScreen()
end
