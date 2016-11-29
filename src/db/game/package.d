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
import db.editor : Editor;
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
	void registerCallbacks()
	{
		registerSystemCallback(MFCallback.FileSystemInit, &catchInitFileSystem);
		registerSystemCallback(MFCallback.InitDone, &catchInit);
		registerSystemCallback(MFCallback.Deinit, &catchDeinit);
		registerSystemCallback(MFCallback.Update, &catchUpdate);
		registerSystemCallback(MFCallback.Draw, &catchDraw);

//		chainResize = registerSystemCallback(MFCallback.DisplayResize, resizeCallback);
		chainResize = registerSystemCallback(MFCallback.DisplayReset, &catchCallback);
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

		doFile("data:flow.lua");

		// TODO: load and show a loading screen...

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
	}

	void deinit()
	{
		ui = null;

		// TODO: eagerly clean this up, since it's GC heap has loads of references to D stuff!
		lua = null;

		renderer.Destroy();
	}

	void update()
	{
		updateInputDevices();

		if (editor)
			editor.update();

		if (performance)
			performance.update();

		ui.update();
	}

	void draw()
	{
		if (performance)
			performance.draw();

		if (editor)
			editor.draw();

		MFView_Push();

		// draw the UI
		renderer.SetCurrentLayer(RenderLayers.UI);

		MFRect rect;
		MFDisplay_GetDisplayRect(&rect);
		MFView_SetOrtho(&rect);

		if (editor)
			editor.drawUi();

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


	// --- lua API ---

	void quit()
	{
		MFSystem_Quit();
	}

	void startPerformance(string song)
	{
		// HACK: create a performance of the first song in the library
		Song* pSong = songLibrary.find(song);
		if (pSong)
		{
			performance = new Performance(pSong, players);
			performance.begin(0);
		}
	}

	void endPerformance()
	{
		performance.release();
		performance = null;
	}

	void pausePerformance(bool bPause)
	{
		performance.pause(bPause);
	}

	void startEditor()
	{
		if (!editor)
			editor = new Editor;
		editor.enter();
	}

	bool inEditor() { return editor && editor.inEditor; }

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
//		registerType!Selectbox();

		LuaTable dbTable = lua.newTable();
		lua["db"] = dbTable;

		// some data accessors
		dbTable["ui"] = Game.instance.ui;

		// register some functions with the VM
		dbTable["quit"] = &Game.instance.quit;
		dbTable["startEditor"] = &Game.instance.startEditor;

		dbTable["themePath"] = &Theme.themePath;
		dbTable["loadUi"] = &Theme.loadUi;
		dbTable["loadUiDescriptor"] = &Theme.loadUiDescriptor;

		dbTable["library"] = Game.instance.songLibrary;

		dbTable["startPerformance"] = &Game.instance.startPerformance;
		dbTable["endPerformance"] = &Game.instance.endPerformance;
		dbTable["pausePerformance"] = &Game.instance.pausePerformance;

		//------
		dbTable["addPlayer"] = &Game.instance.addPlayer;
		dbTable["removePlayer"] = &Game.instance.removePlayer;
	}

	//-------------------------------------------------------------------------------------------------------
	// data
	MFInitParams initParams;
	Settings settings;

	Renderer renderer;

	SongLibrary songLibrary;

	Player[] players;

	Performance performance;

	Editor editor;

	UserInterface ui;
	Theme theme;

	LuaState lua;

	// singleton stuff
	static @property Game instance() { if (_instance is null) _instance = new Game; return _instance; }

	void catchInitFileSystem() nothrow
	{
		try
		{
			initFileSystem();
		}
		catch (Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	void catchInit() nothrow
	{
		try
		{
			init();
		}
		catch (Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	void catchDeinit() nothrow
	{
		try
		{
			deinit();
			_instance = null;
		}
		catch (Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	void catchUpdate() nothrow
	{
		try
		{
			update();
		}
		catch (Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	void catchDraw() nothrow
	{
		try
		{
			draw();
		}
		catch (Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	void catchCallback() nothrow
	{
		try
		{
			if (ui)
			{
				MFRect rect;
				MFDisplay_GetDisplayRect(&rect);

				ui.displayRect = rect;
			}
		}
		catch (Exception e)
		{
			MFDebug_Error(e.msg);
		}
		finally
		{
			if (chainResize)
				chainResize();
		}
	}

private:
	__gshared Game _instance;
	__gshared SystemCallback chainResize;
}
