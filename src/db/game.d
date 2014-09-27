module db.game;

import fuji.fuji;
import fuji.system;
import fuji.filesystem;
import fuji.fs.native;
import fuji.input;
import fuji.display;

import db.tools.log;
import db.renderer;
import db.songlibrary;
import db.theme;
import db.instrument;
import db.player;
import db.profile;
import db.performance;
import db.sequence;
import db.settings;

import db.i.inputdevice;

import db.ui.ui;
import db.ui.layoutdescriptor;
import db.ui.widget;

import db.lua;
import luad.state;

class Game
{
	static void registerCallbacks()
	{
		MFSystem_RegisterSystemCallback(MFCallback.FileSystemInit, &staticInitFileSystem);
		MFSystem_RegisterSystemCallback(MFCallback.InitDone, &staticInit);
		MFSystem_RegisterSystemCallback(MFCallback.Deinit, &staticDeinit);
		MFSystem_RegisterSystemCallback(MFCallback.Update, &staticUpdate);
		MFSystem_RegisterSystemCallback(MFCallback.Draw, &staticDraw);

//		pChainResizeCallback = MFSystem_RegisterSystemCallback(MFCallback.DisplayResize, resizeCallback);
		pChainResizeCallback = MFSystem_RegisterSystemCallback(MFCallback.DisplayReset, &resizeCallback);
	}

	this()
	{
		settings.Load();
	}

	void initFileSystem()
	{
		MFFileSystemHandle hNative = MFFileSystem_GetInternalFileSystemHandle(MFFileSystemHandles.NativeFileSystem);

		MFMountDataNative mountData;
		mountData.priority = MFMountPriority.Normal;
		mountData.flags = MFMountFlags.DontCacheTOC | MFMountFlags.OnlyAllowExclusiveAccess;
		mountData.pMountpoint = "system";
		mountData.pPath = MFFile_SystemPath();
		MFFileSystem_Mount(hNative, mountData);

		mountData.priority = MFMountPriority.Normal;
		mountData.flags = MFMountFlags.FlattenDirectoryStructure | MFMountFlags.Recursive;
		mountData.pMountpoint = "data";
		mountData.pPath = MFFile_SystemPath("data/".ptr);
		MFFileSystem_Mount(hNative, mountData);

		mountData.flags = MFMountFlags.DontCacheTOC | MFMountFlags.OnlyAllowExclusiveAccess;
		mountData.pMountpoint = "cache";
		mountData.pPath = MFFile_SystemPath("cache/".ptr);
		MFFileSystem_Mount(hNative, mountData);

		// songs mounted separately; a network drive for instance
		mountData.flags = MFMountFlags.DontCacheTOC;
		mountData.pMountpoint = "songs";
		mountData.pPath = MFFile_SystemPath("songs/".ptr);
		MFFileSystem_Mount(hNative, mountData);

		Theme.initFilesystem();
	}

	void init()
	{
		renderer = new Renderer;

		// enable buffered input (200hz == 5ms precision)
		MFInput_EnableBufferedInput(true, 200);

		// TODO: auto-detect instruments (controllers, midi/audio devices)
		InputDevice[] inputs = detectInstruments();

		// create song library
		songLibrary = new SongLibrary();

		// scan for new songs
		songLibrary.scan();

		// save the settings (detected inputs and stuff)
		saveSettings();

		// init the lua VM
		lua = initLua();

		// init UI
		MFRect rect;
		MFDisplay_GetDisplayRect(&rect);

		ui = new UserInterface(rect);
		UserInterface.setActive(ui);

		// load the bootup UI
		LayoutDescriptor desc = new LayoutDescriptor("boot.xml");
		if(desc)
		{
			Widget boot = desc.spawn();
			if(boot)
				ui.addTopLevelWidget(boot);
		}

		// TODO: the following stuff should all be asynchronous with a loading screen:

		// HACK: configure a player for each detected input
		int i = 0;
		foreach(input; inputs)
		{
			Player player = new Player;

			player.profile = new Profile;
			player.profile.name = "Player " ~ to!string(i++);

			player.input.device = input;
			if(input.instrumentType == InstrumentType.GuitarController)
				player.input.part = Part.LeadGuitar;
			else if(input.instrumentType == InstrumentType.Drums)
				player.input.part = Part.Drums;
			else if(input.instrumentType == InstrumentType.Keyboard)
				player.input.part = Part.ProKeys;
			else if(input.instrumentType == InstrumentType.Dance)
				player.input.part = Part.Dance;
			else
				player.input.part = Part.Unknown;

			players ~= player;
		}

		// HACK: create a performance of the first song in the library
		Track* track = songLibrary.find("silvertear-so_deep-perfect_sphere_remix");
		if(track)
		{
			performance = new Performance(track, players);
			performance.Begin();
		}

		// load the theme
		theme = Theme.load(settings.theme);
		if(!theme)
			theme = Theme.load("Default");
		if(!theme)
		{
			MFDebug_Warn(2, "Couldn't load theme!".ptr);
			return;
		}

		ui.addTopLevelWidget(theme.ui);
	}

	void deinit()
	{
		ui = null;

		renderer.Destroy();
	}

	void update()
	{
		if(performance)
			performance.Update();

		ui.update();
	}

	void draw()
	{
		if(performance)
		{
			performance.Draw();
		}
		else
		{
			// where are we? in menus and stuff?
		}

		MFView_Push();

		// draw the UI
		renderer.SetCurrentLayer(RenderLayers.UI);

		MFRect rect;
		MFDisplay_GetDisplayRect(&rect);
		MFView_SetOrtho(&rect);

		ui.draw();

		// render debug stuff...
		renderer.SetCurrentLayer(RenderLayers.Debug);

		rect = MFRect(0, 0, 1920, 1080);
		MFView_SetOrtho(&rect);

		DrawLog();

		MFView_Pop();
	}

	void saveSettings()
	{
		settings.Save();
	}

	//-------------------------------------------------------------------------------------------------------
	// data
	MFInitParams initParams;
	Settings settings;

	Renderer renderer;

	SongLibrary songLibrary;

	Player[] players;

	Performance performance;

	UserInterface ui;
	Theme theme;

	LuaState lua;

	// singleton stuff
	static @property Game instance() { if(_instance is null) _instance = new Game; return _instance; }

	static extern (C) void staticInitFileSystem() nothrow
	{
		try
		{
			_instance.initFileSystem();
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	static extern (C) void staticInit() nothrow
	{
		try
		{
			_instance.init();
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	static extern (C) void staticDeinit() nothrow
	{
		try
		{
			_instance.deinit();
			_instance = null;
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	static extern (C) void staticUpdate() nothrow
	{
		try
		{
			_instance.update();
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	static extern (C) void staticDraw() nothrow
	{
		try
		{
			_instance.draw();
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	static extern(C) void resizeCallback() nothrow
	{
		try
		{
			if(_instance.ui)
			{
				MFRect rect;
				MFDisplay_GetDisplayRect(&rect);

				_instance.ui.displayRect = rect;
			}
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
		finally
		{
			if(pChainResizeCallback)
				pChainResizeCallback();
		}
	}

private:
	__gshared Game _instance;
	__gshared MFSystemCallbackFunction pChainResizeCallback;
}
