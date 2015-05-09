-- Default theme --

print "Loaded 'Default' theme..."

theme = {}

function begin(source)

	-- collect some references to various UI elements
	theme.ui = ui:find("theme")
	theme.playerui = {}

	local players = theme.ui:findChild("players")
	for i = 1, 8 do
		theme.playerui[i] = players:findChild("player" .. i-1)
	end

	-- register input function to handle global key presses
	db.setInputHandler(function(ev, inputManager)
		-- handle global 'back' button
		if ev.ev == "ButtonDown" and ev.device == "Keyboard" and (ev.buttonID == 27 or ev.buttonID == 8) then
			db.showPrevScreen()
			return true
		end

		-- new players join
		if ev.ev == "ButtonDown" and
		  (ev.device == "Keyboard" and (ev.buttonID == 13 or ev.buttonID == 32)) or
		  (ev.device == "Gamepad" and ev.buttonID == 8) and not ev.pSource.player then
			newplayer(ev.pSource)
		end
	end)

	-- make the theme visible
	theme.ui.visibility = "Visible"

	-- and show the mainmenu
	db.showScreen("mainmenu", true)

	-- do we want to allow the player to sign in?
	newplayer(source)
end

function newplayer(source)
	-- if the player is already bound, don't make a new one
	-- TODO: doesn't work, since pointers can't be compared to nil (pointer and nil are different types)
	if source.player then
		print("alrady exists")
		return
	end

	-- create the player
	for i = 1, 8 do
		if theme.playerui[i].data.player == nil then
			local player = Player(source)

			print("enter player " .. i)
			player.data.ui = theme.playerui[i]
			player.data.ui.data.player = player

			addPlayer(player)
			player.data.ui.visibility = "visible"
			break
		end
	end
end

function signin(player)
	-- show the sign-in ui?
end
