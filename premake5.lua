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
	local linkFujiDirectly = not os.is("linux") or true
	if linkFujiDirectly then
--		fujiDll = true
		dofile  "fuji/Fuji/Project/fujiproj.lua"
		dofile  "fuji/Fuji/Project/fujidproj.lua"
	end

	-- include the Haku project...
--	dofile "fuji/Haku/Project/hakuproj.lua"

	project "FeedBack"
		kind "WindowedApp"
		language "D"

		files { "src/**.d" }
		includedirs { "src/" }

		links { "Fuji", "FujiD" }

		targetname "FeedBack"
--		targetdir "bin"
		objdir "build"

		dofile "fuji/dist/Project/fujiconfig.lua"
--		dofile "fuji/dist/Project/hakuconfig.lua"

		configuration { "windows" }
			links { "Gdi32.lib", "Ole32.lib", "oleaut32.lib" }
			links { "FujiMiddleware.lib" }
