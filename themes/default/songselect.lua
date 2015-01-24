local songselect = db.getScreen("songselect")

songselect.onEnter = function()
	if songselect.element then
		songselect.element.visibility = "Visible"
	end

	-- set input device focus to default widgets...
end

songselect.onExit = function()
	if songselect.element then
		songselect.element.visibility = "Invisible"
	end
end


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

	startPerformance(song)

	db.showScreen("performance")
end
