-- FeedBack bootup script --

function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
  	if k ~= "package" and k ~= "_G" then
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    else
      print(formatting .. tostring(v))
    end
    end
  end
end

-- This script will execute on creation of the boot.xml UI
print "Boot script..."

--local w = Widget:new()
--tprint(_G)
--local w = Widget:new()
--print w.typeName
