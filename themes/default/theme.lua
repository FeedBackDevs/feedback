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

function selectSong(w, ev)
	print("select Song!")
end

function playSong(w, ev)
	print("Play Song")
end

function selectPlaySong(w, ev)
	print("select play song!")
	ui:find("mainmenu").visibility = "Invisible"
	ui:find("songselect").visibility = "Visible"
end

function selectSettings(w, ev)
	print("select settings!")
end

function selectExit(w, ev)
	print("select exit")
	quit()
end