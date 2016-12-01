-- themes/default/theme.lua

print("default theme...")

theme = {}

dofile(db.themePath("flow.lua"))

function theme.isMenuDevice(source)
	local s = source.deref
	if s.device == theme.masterDevice and s.deviceID == theme.masterDeviceId then
		return true
	end
	return false
end
