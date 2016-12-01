-- themes/default/screens/songselect.lua

theme.songselect = flow.newScreen("songselect")
local m = theme.songselect


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
hax = {}
hax.songs = ArrayAdapter(db.library.songs, get, update)


function m:onInit(...)
end
function m:onEnter()
	self.panel = flow.attachPanel(self, "playerpanel", "players")
end
function m:onLeave()
	flow.detachPanel(self.panel)
end
function m:onInput(ev, inputManager)
	if self.panel:onInput(ev, inputManager) then
		return true
	end

	-- ...
end


function m:selectSong(index)
end
function m:playSong(index)
	if index ~= 0 then
		local song = db.library.songs[index]
		db.startPerformance(song)

		flow.pushScreen("performance")
	end
end
function m:back()
	flow.popScreen()
end

return m
