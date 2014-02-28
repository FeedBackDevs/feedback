require "monodevelop"
require "d"

solution "FeedBack"
	if _ACTION == "gmake" then
		configurations { "Release", "Debug", "DebugOpt", "Retail" }
	else
		configurations { "Debug", "DebugOpt", "Release", "Retail" }
		platforms { "x64" }
	end

	-- include the fuji project...
--	fujiDll = true
	dofile  "../fuji/Fuji/Project/fujiproj.lua"
	dofile  "../fuji/Fuji/Project/fujidproj.lua"

	-- include the Haku project...
--	dofile "../fuji/Haku/Project/hakuproj.lua"

	project "FeedBack"
		kind "WindowedApp"
		language "D"

		files { "src/**.d" }

		includedirs { "src/" }
		libdirs { "../fuji/dist/lib/x64" }

		links { "Fuji", "FujiD" }

		targetname "FeedBack"
--		targetdir "bin"
		objdir "build"

		configuration { "windows" }
			links { "Gdi32.lib", "Ole32.lib", "oleaut32.lib" }

			configuration { "windows", "x32 or native" }
				links { "FujiAsset32.lib" }
				linkoptions { "/DelayLoad:FujiAsset32.dll" }
			configuration { "windows", "x64" }
				links { "FujiAsset64.lib" }
				linkoptions { "/DelayLoad:FujiAsset64.dll" }

		dofile "../fuji/dist/Project/fujiconfig.lua"
--		dofile "../fuji/dist/Project/hakuconfig.lua"

