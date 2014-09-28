-- Default theme --

print "Loaded 'Default' theme..."



-- song selector

local function get(item, userdata)
	local l = Label()
	l.textColour = MFVector.white
	l.text = item
	return l
end
local function update(item, layout, userdata)
	layout.text = item
	print("update layout!")
end

songs = ArrayAdapter(library.songs, get, update)

function select(w, ev)
	print("select!")
end
function begin(w, ev)
	print("begin!")
end
