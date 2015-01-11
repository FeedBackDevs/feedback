-- Default theme --

print "Loaded 'Default' theme..."

function begin()
	ui:find("theme").visibility = "Visible"
	ui:find("mainmenu").visibility = "Visible"
	-- set input device focus to default widgets...
end


-- song selector

local function get(item, userdata)
	local l = Label()
	l.textColour = Vector.white
	l.text = item
	return l
end
local function update(item, layout, userdata)
	layout.text = item
	print("update layout!")
end
songs = ArrayAdapter(library.songs, get, update)

function selectSong(w, i)
	if i > 0 then
		local song = library.songs[i]
		print("Select Song: " .. song)
	end
end

function playSong(w, i)
	print("Play Song")

	local song = library.songs[i]

	local s = library:find(song)
	if s then
		print(s.deref.artist .. " " .. s.deref.name)
	end

	startPerformance(song);

	ui:find("songselect").visibility = "Invisible"
	ui:find("performance").visibility = "Visible"
end

function selectPlaySong()
	print("select play song!")
	ui:find("mainmenu").visibility = "Invisible"
	ui:find("songselect").visibility = "Visible"
end

function selectSettings()
	print("select settings!")
end

function selectExit()
	print("select exit")
	quit()
end
