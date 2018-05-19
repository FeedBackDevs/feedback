--require "monodevelop"
require "d"

solution "FeedBack"
	if _ACTION == "gmake" then
		configurations { "Release", "Debug", "DebugOpt", "Retail" }
	else
		configurations { "Debug", "DebugOpt", "Release", "Retail" }
		platforms { "x64" }
	end

	-- include the fuji project...
	local linkFujiDirectly = not os.istarget("linux") or true
	if linkFujiDirectly then
--		fujiDll = true
		dofile  "fuji/Fuji/Project/fujiproj.lua"
		dofile  "fuji/Fuji/Project/fujidproj.lua"
	end

	-- LuaD project
	project "LuaD"
		language "C++"
		kind "StaticLib"
		staticruntime "On"
		flags { "OmitDefaultLibrary" }

		-- setup paths --
		files { "LuaD/luad/**.d" }
		importdirs { "LuaD/" }

		targetname "luad"
		targetdir("lib")
		objdir "build"

		dofile "fuji/dist/Project/fujiconfig.lua"

		configuration { }

	-- FeedBack project
	project "FeedBack"
		kind "WindowedApp"
		language "C++"

		files { "src/**.d" }
		importdirs { "src/", "LuaD/" }

		-- include 'code' data
		files { "data/**.lua", "data/**.xml", "data/**.ini", "data/**.mfx", "data/**.hlsl", "data/**.glsl" }
		files { "themes/**.lua", "themes/**.xml" }

		libdirs { "lib" }
		links { "Fuji", "FujiD", "LuaD" }

		targetname "FeedBack"
--		targetdir "bin"
		objdir "build"

		dofile "fuji/dist/Project/fujiconfig.lua"
--		dofile "fuji/dist/Project/hakuconfig.lua"

		configuration { "windows" }
			links { "Gdi32.lib", "Ole32.lib", "oleaut32.lib" }
			links { "FujiMiddleware.lib" }
			links { "lua.lib" }

		configuration { "linux" }
			links { "lua5.1.a" }

