module db.game;

import fuji.fuji;
import fuji.system;
import fuji.filesystem;
import fuji.fs.native;
import fuji.input;
import fuji.display;

import db.tools.log;
import db.renderer;
import db.library;
import db.theme;
import db.instrument;
import db.game.player;
import db.profile;
import db.game.performance;
import db.chart.track : Track;
import db.settings;

import db.inputs.inputdevice;
import db.inputs.devicemanager;

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
		UserInterface.registerWidgets();

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

		// register instrument types
		registerBuiltinInstrumentTypes();

		// detect input devices
		initInputDevices();

		// create song library
		songLibrary = new SongLibrary();

		// save the settings (detected inputs and stuff)
		saveSettings();

		// init UI
		MFRect rect;
		MFDisplay_GetDisplayRect(&rect);

		ui = new UserInterface(rect);
		UserInterface.active = ui;

		// init the lua VM
		lua = initLua();
		luaRegister();

		// load the bootup UI
		doFile("boot.lua");
		LayoutDescriptor desc = new LayoutDescriptor("boot.xml");
		if (desc)
		{
			Widget boot = desc.spawn();
			if (boot)
				ui.addTopLevelWidget(boot);
		}

		// TODO: the following stuff should all be asynchronous with a loading screen:

		// scan for new songs
		songLibrary.scan();

		// load the theme
		theme = Theme.load(settings.theme);
		if (!theme)
			theme = Theme.load("Default");
		if (!theme)
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
		updateInputDevices();

		if (performance)
			performance.Update();

		ui.update();
	}

	void draw()
	{
		if (performance)
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

	void startPerformance(string song)
	{
		// HACK: create a performance of the first song in the library
		Song* pSong = songLibrary.find(song);
		if (pSong)
		{
			performance = new Performance(pSong, players);
			performance.Begin();
		}
	}

	void endPerformance()
	{
		performance.Release();
		performance = null;
	}

	void pausePerformance(bool bPause)
	{
		performance.Pause(bPause);
	}

	void addPlayer(Player player)
	{
		players ~= player;
	}

	void removePlayer(Player player)
	{
		foreach (i, p; players)
		{
			if (p == player)
			{
				players = players[0..i] ~ players[i+1..$];
				break;
			}
		}
	}

	void luaRegister()
	{
		import db.ui.widgets.label;
		import db.ui.widgets.button;
		import db.ui.widgets.prefab;
		import db.ui.widgets.layout;
		import db.ui.widgets.frame;
		import db.ui.widgets.linearlayout;
		import db.ui.widgets.textbox;
		import db.ui.widgets.listbox;

		import fuji.types;
		import fuji.vector;
		import fuji.matrix;
		import fuji.quaternion;

		// register some functions with the VM
		lua["quit"] = &MFSystem_Quit;
		lua["startPerformance"] = &Game.instance.startPerformance;
		lua["endPerformance"] = &Game.instance.endPerformance;
		lua["pausePerformance"] = &Game.instance.pausePerformance;

		lua["addPlayer"] = &Game.instance.addPlayer;
		lua["removePlayer"] = &Game.instance.removePlayer;

		lua["library"] = Game.instance.songLibrary;
		lua["ui"] = Game.instance.ui;

		// Fuji enums
		registerType!MFKey();

		// Fuji types
		registerType!(MFRect, "Rect")();
		registerType!(MFVector, "Vector")();
		registerType!(MFQuaternion, "Quaternion")();
		registerType!(MFMatrix, "Matrix")();

		// Game objects
		registerType!Player();
		registerType!Profile();

		// UI
		registerType!(LuaArrayAdaptor, "ArrayAdapter")();

		// Widgets
		registerType!Widget();
		registerType!Label();
		registerType!Button();
		registerType!Prefab();
		registerType!Frame();
		registerType!LinearLayout();
		registerType!Textbox();
		registerType!Listbox();
		//	registerType!Selectbox();
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
	static @property Game instance() { if (_instance is null) _instance = new Game; return _instance; }

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
			if (_instance.ui)
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
			if (pChainResizeCallback)
				pChainResizeCallback();
		}
	}

private:
	__gshared Game _instance;
	__gshared MFSystemCallbackFunction pChainResizeCallback;
}
