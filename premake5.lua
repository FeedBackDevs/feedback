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

	-- LuaD project
	project "LuaD"
		language "D"
		kind "StaticLib"
		flags { "StaticRuntime", "OmitDefaultLibrary" }

		-- setup paths --
		files { "LuaD/luad/**.d" }
		includedirs { "LuaD/" }

		targetname "luad"
		targetdir("lib")
		objdir "build"

		dofile "fuji/dist/Project/fujiconfig.lua"

		configuration "Release"
			flags { "NoBoundsCheck" }
		configuration "Retail"
			flags { "NoBoundsCheck" }

		configuration { }

	-- FeedBack project
	project "FeedBack"
		kind "WindowedApp"
		language "D"

		files { "src/**.d" }
		includedirs { "src/", "LuaD/" }

		libdirs { "lib" }
		links { "Fuji", "FujiD", "LuaD" }

		targetname "FeedBack"
--		targetdir "bin"
		objdir "build"

		dofile "fuji/dist/Project/fujiconfig.lua"
--		dofile "fuji/dist/Project/hakuconfig.lua"

		configuration "Release"
			flags { "NoBoundsCheck" }
		configuration "Retail"
			flags { "NoBoundsCheck" }

		configuration { "windows" }
			links { "Gdi32.lib", "Ole32.lib", "oleaut32.lib" }
			links { "FujiMiddleware.lib" }
			links { "lua.lib" }

		configuration { "linux" }
			links { "lua5.1.a" }

