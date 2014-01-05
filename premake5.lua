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
	dofile  "../Fuji/Fuji/Project/fujiproj.lua"

	-- include the Haku project...
--	dofile "../Fuji/Haku/Project/hakuproj.lua"

	project "FeedBack"
		kind "WindowedApp"
		language "D"

		files { "src/**.d" }
		files { "../Fuji/dist/include/d2/fuji/**.d" }

		includedirs { "../Fuji/dist/include/d2/" }
		libdirs { "../Fuji/dist/lib/x64" }

		links { "Fuji" }

		targetname "FeedBack"
--		targetdir "bin"
		objdir "build"

		configuration { "windows" }
			links { "Gdi32.lib", "Ole32.lib", "oleaut32.lib" }

		dofile "../Fuji/dist/Project/fujiconfig.lua"
--		dofile "../Fuji/dist/Project/hakuconfig.lua"
