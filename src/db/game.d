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

class Game
{
	this()
	{
		settings.Load();
	}

	void InitFileSystem()
	{
		MFFileSystemHandle hNative = MFFileSystem_GetInternalFileSystemHandle(MFFileSystemHandles.NativeFileSystem);
		MFMountDataNative mountData;
		mountData.priority = MFMountPriority.Normal;
		mountData.flags = MFMountFlags.FlattenDirectoryStructure | MFMountFlags.Recursive;
		mountData.pMountpoint = "data";
		mountData.pPath = MFFile_SystemPath("data/".ptr);
		MFFileSystem_Mount(hNative, mountData);

		mountData.flags = MFMountFlags.DontCacheTOC;
		mountData.pMountpoint = "cache";
		mountData.pPath = MFFile_SystemPath("data/cache".ptr);
		MFFileSystem_Mount(hNative, mountData);

		// songs mounted separately, remocated to a network drive for instance
		mountData.flags = MFMountFlags.DontCacheTOC;
		mountData.pMountpoint = "songs";
		mountData.pPath = MFFile_SystemPath("data/Songs".ptr);
		MFFileSystem_Mount(hNative, mountData);
	}

	void Init()
	{
		renderer = new Renderer;

		// TODO: the following stuff should all be asynchronous with a loading screen:

		// TODO: scan for dongs (we should cache this data...)
		songLibrary = new SongLibrary;
		songLibrary.Scan();

		// enable buffered input
		MFInput_EnableBufferedInput(true);

		// TODO: auto-detect instruments (controllers, midi/audio devices)
		InputDevice[] inputs = DetectInstruments();

		// save the settings (detected inputs and stuff)
		SaveSettings();

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
		if(songLibrary.songs.length != 0)
		{
			performance = new Performance(songLibrary.songs[0], players);
			performance.Begin();
		}

		// init UI
		MFRect rect;
		MFDisplay_GetDisplayRect(&rect);

		ui = new UserInterface(rect);

		__gshared MFSystemCallbackFunction pChainResizeCallback;
		extern(C) static void resizeCallback() nothrow
		{
			try
			{
				UserInterface ui = UserInterface.getActive();
				if(ui)
				{
					MFRect rect;
					MFDisplay_GetDisplayRect(&rect);

					ui.displayRect = rect;
				}
			}
			catch(Exception e)
			{
				MFDebug_Error(e.msg.toStringz);
			}
			finally
			{
				if(pChainResizeCallback)
					pChainResizeCallback();
			}
		}

//		pChainResizeCallback = MFSystem_RegisterSystemCallback(MFCallback.DisplayResize, resizeCallback);
		pChainResizeCallback = MFSystem_RegisterSystemCallback(MFCallback.DisplayReset, &resizeCallback);

		UserInterface.setActive(ui);

		// load a test UI
/+
		LayoutDescriptor desc = new LayoutDescriptor("ui-test.xml");
		Widget testLayout = desc.spawn();
//		Widget testLayout = HKWidget_CreateFromXML("ui-test.xml");
//		MFDebug_Assert(pTestLayout != NULL, "Couldn't load UI!");

		ui.addTopLevelWidget(testLayout);
+/
	}

	void Deinit()
	{
		ui = null;

		renderer.Destroy();
	}

	void Update()
	{
		if(performance)
			performance.Update();

		ui.update();
	}

	void Draw()
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

	void SaveSettings()
	{
		settings.Save();
	}

	// data
	MFInitParams initParams;

	Settings settings;

	Renderer renderer;

	SongLibrary songLibrary;

	Player[] players;

	Performance performance;

	UserInterface ui;

	// singleton stuff
	static @property Game Instance() { if(instance is null) instance = new Game; return instance; }

	static extern (C) void Static_InitFileSystem() nothrow
	{
		try
		{
			instance.InitFileSystem();
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	static extern (C) void Static_Init() nothrow
	{
		try
		{
			instance.Init();
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	static extern (C) void Static_Deinit() nothrow
	{
		try
		{
			instance.Deinit();
			instance = null;
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	static extern (C) void Static_Update() nothrow
	{
		try
		{
			instance.Update();
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

	static extern (C) void Static_Draw() nothrow
	{
		try
		{
			instance.Draw();
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}

private:
	__gshared Game instance;
}
