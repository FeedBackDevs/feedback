--
-- d/tools/ldc.lua
-- Provides LDC-specific configuration strings.
-- Copyright (c) 2013-2014 Andrew Gough, Manu Evans, and the Premake project
--

	premake.tools.ldc = { }

	local ldc = premake.tools.ldc
	local project = premake.project
	local config = premake.config
    local d = premake.extensions.d


--
-- Set default tools
--

	ldc.dc = "ldc2"
	ldc.namestyle = "posix"


--
-- Returns list of D compiler flags for a configuration.
--


	ldc.dflags = {
		architecture = {
			x32 = "-m32",
			x64 = "-m64",
--			arm = "-march=arm",
--			ppc = "-march=ppc32",
--			ppc64 = "-march=ppc64",
--			spu = "-march=cellspu",
--			mips = "-march=mips",	-- -march=mipsel?
		},
		flags = {
			Deprecated		= "-d",
			Documentation	= "-D",
			FatalWarnings	= "-w", -- Use LLVM flag? : "-fatal-assembler-warnings",
			GenerateHeader	= "-H",
			GenerateJSON	= "-X",
			NoBoundsCheck	= "-disable-boundscheck",
--			Release			= "-release",
			RetainPaths		= "-op",
			Symbols			= "-g",
			SymbolsLikeC	= "-gc",
			UnitTest		= "-unittest",
			Verbose			= "-v",
		},
		floatingpoint = {
			Fast = "-fp-contract=fast -enable-unsafe-fp-math",
--			Strict = "-ffloat-store",
		},
		kind = {
			SharedLib = function(cfg)
				if cfg.system ~= premake.WINDOWS then return "-relocation-model=pic" end
			end,
		},
		optimize = {
			Off = "-O0",
			On = "-O2",
			Debug = "-O0",
			Full = "-O3",
			Size = "-Oz",
			Speed = "-O3",
		},
		vectorextensions = {
			SSE = "-mattr=+sse",
			SSE2 = "-mattr=+sse2",
		},
		warnings = {
			Default = "-wi",
			Extra = "-wi",	-- TODO: is there a way to get extra warnings?
		}
	}

	function ldc.getdflags(cfg)
		local flags = config.mapFlags(cfg, ldc.dflags)

		if config.isDebugBuild(cfg) then
			table.insert(flags, "-d-debug")
		else
			table.insert(flags, "-release")
		end

		-- TODO: When DMD gets CRT options, map StaticRuntime and DebugRuntime

		if cfg.flags.Documentation then
			if cfg.docname then
				table.insert(flags, "-Df=" .. premake.quoted(cfg.docname))
			end
			if cfg.docdir then
				table.insert(flags, "-Dd=" .. premake.quoted(cfg.docdir))
			end
		end
		if cfg.flags.GenerateHeader then
			if cfg.headername then
				table.insert(flags, "-Hf=" .. premake.quoted(cfg.headername))
			end
			if cfg.headerdir then
				table.insert(flags, "-Hd=" .. premake.quoted(cfg.headerdir))
			end
		end

		return flags
	end


--
-- Decorate versions for the DMD command line.
--

	function ldc.getversions(versions, level)
		local result = {}
		for _, version in ipairs(versions) do
			table.insert(result, '-d-version=' .. version)
		end
		if level then
			table.insert(result, '-d-version=' .. level)
		end
		return result
	end


--
-- Decorate debug constants for the DMD command line.
--

	function ldc.getdebug(constants, level)
		local result = {}
		for _, constant in ipairs(constants) do
			table.insert(result, '-d-debug=' .. constant)
		end
		if level then
			table.insert(result, '-d-debug=' .. level)
		end
		return result
	end


--
-- Decorate import file search paths for the DMD command line.
--

	function ldc.getimportdirs(cfg, dirs)
		local result = {}
		for _, dir in ipairs(dirs) do
			dir = project.getrelative(cfg.project, dir)
			table.insert(result, '-I=' .. premake.quoted(dir))
		end
		return result
	end


--
-- Returns the target name specific to compiler
--

	function ldc.gettarget(name)
		return "-of=" .. name
	end


--
-- Return a list of LDFLAGS for a specific configuration.
--

	ldc.ldflags = {
		architecture = {
			x32 = { "-m32", "-L=-L/usr/lib" },
			x64 = { "-m64", "-L=-L/usr/lib64" },
		},
		kind = {
			SharedLib = "-shared",
			StaticLib = "-lib",
		},
	}

	function ldc.getldflags(cfg)
		local flags = config.mapFlags(cfg, ldc.ldflags)

		-- Scan the list of linked libraries. If any are referenced with
		-- paths, add those to the list of library search paths
--		for _, dir in ipairs(config.getlinks(cfg, "all", "directory")) do  -- TODO: why use 'all'?
		for _, dir in ipairs(config.getlinks(cfg, "system", "directory")) do
			table.insert(flags, '-L=-L' .. project.getrelative(cfg.project, dir))
		end

		return flags
	end


--
-- Return the list of libraries to link, decorated with flags as needed.
--

	function ldc.getlinks(cfg, systemonly)
		local result = {}

		local links
		if not systemonly then
			links = config.getlinks(cfg, "siblings", "object")
			for _, link in ipairs(links) do
				-- skip external project references, since I have no way
				-- to know the actual output target path
				if not link.project.external then
					if link.kind == premake.STATICLIB then
						-- Don't use "-l" flag when linking static libraries; instead use
						-- path/libname.a to avoid linking a shared library of the same
						-- name if one is present
						table.insert(result, "-L=" .. project.getrelative(cfg.project, link.linktarget.abspath))
					else
						table.insert(result, "-L=-l" .. link.linktarget.basename)
					end
				end
			end
		end

		-- The "-l" flag is fine for system libraries
		links = config.getlinks(cfg, "system", "fullpath")
		for _, link in ipairs(links) do
			if path.isframework(link) then
				table.insert(result, "-framework " .. path.getbasename(link))
			elseif path.isobjectfile(link) then
				table.insert(result, "-L=" .. link)
			else
				table.insert(result, "-L=-l" .. path.getbasename(link))
			end
		end

		return result
	end


--
-- Returns makefile-specific configuration rules.
--

	ldc.makesettings = {
	}

	function ldc.getmakesettings(cfg)
		local settings = config.mapFlags(cfg, ldc.makesettings)
		return table.concat(settings)
	end


--
-- Retrieves the executable command name for a tool, based on the
-- provided configuration and the operating environment.
--
-- @param cfg
--    The configuration to query.
-- @param tool
--    The tool to fetch, one of "dc" for the D compiler, or "ar" for the static linker.
-- @return
--    The executable command name for a tool, or nil if the system's
--    default value should be used.
--

	ldc.tools = {
		-- I think this is pointless; LDC uses compile flags to choose target architecture no?
	}

	function ldc.gettoolname(cfg, tool)
		local names = ldc.tools[cfg.architecture] or ldc.tools[cfg.system] or {}
		local name = names[tool]
		return name or ldc[tool]
	end
