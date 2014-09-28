-- FeedBack bootup script --

-- This script will execute on creation of the boot.xml UI
print "Boot script..."

function bootScreenClick()
	ui:find("boot").visibility = "Gone"
	begin()
end
