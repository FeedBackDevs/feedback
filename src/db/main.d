module db.main;

import core.runtime;
import std.range : isForwardRange, ElementType;

import fuji.fuji;
import fuji.system;
import fuji.display;

import db.game;

// HAX: early-init fuji for the command line tools...
extern (C) bool MFModule_InitModules();

version(Windows)
{
	// HACK: Linking against dynamic MSCRT seems to lost a symbol?!
	extern(C) __gshared const(double) __imp__HUGE = double.infinity;

	import core.sys.windows.windows;
	extern (Windows) int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
	{
		int result;

		Runtime.initialize();

		try
		{
			import std.algorithm : splitter, map;
			import std.range : array;

			Game game = Game.instance;

			game.initParams.hInstance = hInstance;
			game.initParams.pCommandLine = lpCmdLine;

			gDefaults.plugin.renderPlugin = game.settings.videoDriver;
			gDefaults.plugin.soundPlugin = game.settings.audioDriver;

			gDefaults.input.useXInput = false;

			result = Start("program.exe" ~ lpCmdLine.toDStr.splitter.map!(e => e.idup).array);
		}
		catch (Throwable o)		// catch any uncaught exceptions
		{
			MessageBoxA(null, cast(char *)o.toString(), "Error", MB_OK | MB_ICONEXCLAMATION);
			result = 0;		// failed
		}

		Runtime.terminate();

		return result == -1 ? 0 : result;
	}
}
else
{
	int main(string[] args)
	{
		int result;

		try
		{
			Game game = Game.instance;

			const(char)*[] argv;
			foreach (arg; args)
				argv ~= arg.ptr;

			game.initParams.argc = cast(int)args.length;
			game.initParams.argv = argv.ptr;

			result = Start(args);
		}
		catch (Throwable o)		// catch any uncaught exceptions
		{
			result = 0;		// failed
		}

		return result;
	}
}

int Start(string[] args)
{
	gDefaults.midi.useMidi = true;

	Game game = Game.instance;

	game.initParams.hideSystemInfo = false;

//	MFRect failure;
//	MFDisplay_GetNativeRes(&failure);
//	game.initParams.display.displayRect.width = failure.width;
//	game.initParams.display.displayRect.height = failure.height;
//	game.initParams.display.bFullscreen = true;
	game.initParams.pAppTitle = "FeedBack".ptr;

	Fuji_CreateEngineInstance();

	import fuji.modules;
	MFModule_RegisterCoreModules();
	MFModule_InitModules();

	int r = doCommandLine(args);
	if (r == 0)
	{
		game.registerCallbacks();
		// MADHAX: call this here, since it won't be called by the MFModule_InitModules() which was already called!
		game.initFileSystem();

		r = MFMain(game.initParams);
	}

	Fuji_DestroyEngineInstance();

	return r == -1 ? 0 : r;
}

int doCommandLine(string[] args)
{
	import std.getopt;
	string convert;
	getopt(args,
		"convert", "Convert foreign data to .chart format", &convert	// string
	);

	int result = 0;

	if (convert)
	{
		import fuji.filesystem;
		import fuji.fs.native;
		MFFileSystemHandle hNative = MFFileSystem_GetInternalFileSystemHandle(MFFileSystemHandles.NativeFileSystem);

		MFMountDataNative mountData;
		mountData.priority = MFMountPriority.Normal;
		mountData.flags = MFMountFlags.DontCacheTOC;
		mountData.pMountpoint = "system";
		mountData.pPath = MFFile_SystemPath();
		int mount = MFFileSystem_Mount(hNative, mountData);

		// load source and save chart...
		result = convertChart(convert);

		MFFileSystem_Dismount("system");
	}

	return result;
}

int convertChart(string file)
{
	import std.path;
	import std.uni : icmp;

	import db.chart;
	import db.formats.ghrbmidi : LoadGHRBMidi;
	import db.formats.rawmidi : LoadRawMidi;
	import db.formats.gtp : LoadGuitarPro;
	import db.formats.sm : LoadSM;
	import db.formats.dwi : LoadDWI;
	import db.formats.ksf : LoadKSF;
	import db.library : Song;

	Song song;

	if (file.baseName.extension.icmp(".chart") == 0)
	{
		Chart c = new Chart(file);
		if (!c)
		{
			logMessage(file ~ " is not a .chart file!");
			return 1;
		}

		if (c.params["source_format"][] == ".chart_1_0")
		{
			c.saveChart(file.dirName);
			return -1;
		}
		else
		{
			logMessage(file ~ " is already a .chart v2 file!");
			return -1;
		}
	}
	else if (file.baseName.icmp("song.ini") == 0)
	{
		if (!LoadGHRBMidi(&song, file))
		{
			logMessage("Failed to convert GH/RB chart!");
			return 1;
		}
		song._chart.saveChart(file.dirName);
		return -1;
	}
	else if (file.baseName.extension.icmp(".sm") == 0)
	{
		if (!LoadSM(&song, file))
		{
			logMessage("Failed to convert StepMania chart!");
			return 1;
		}
		song._chart.saveChart(file.dirName);
		return -1;
	}
	else if (file.baseName.extension.icmp(".dwi") == 0)
	{
		if (!LoadDWI(&song, file))
		{
			logMessage("Failed to convert Dance With Intensity chart!");
			return 1;
		}
		song._chart.saveChart(file.dirName);
		return -1;
	}
	else if (file.baseName.extension.icmp(".gtp") == 0 ||
			 file.baseName.extension.icmp(".gp3") == 0 ||
			 file.baseName.extension.icmp(".gp4") == 0 ||
			 file.baseName.extension.icmp(".gp5") == 0 ||
			 file.baseName.extension.icmp(".gpx") == 0)
	{
		if (!LoadGuitarPro(&song, file))
		{
			logMessage("Failed to convert Guitar Pro chart!");
			return 1;
		}
		song._chart.saveChart(file.dirName);
		return -1;
	}
	else if (file.baseName.extension.icmp(".mid") == 0)
	{
		if (file.baseName.icmp("notes.mid") == 0)
		{
			logMessage("To convert GH/RB midi files, give 'song.ini' as the filename!");
			return 1;
		}
		if (!LoadRawMidi(&song, file))
		{
			logMessage("Failed to convert MIDI chart!");
			return 1;
		}
		song._chart.saveChart(file.dirName);
		return -1;
	}

	return -1; // termiante with success
}
