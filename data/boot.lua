-- FeedBack bootup script --

-- This script will execute on creation of the boot.xml UI
print "Boot script..."

ui:registerUnhandledInputHandler(function(inputManager, ev)
	print("unhandled input!")
	return false
end)

function bootScreenClick()
	ui:find("boot").visibility = "Gone"
	begin()
end

