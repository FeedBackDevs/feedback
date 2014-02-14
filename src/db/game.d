module db.game;

import fuji.fuji;
import fuji.system;
import fuji.filesystem;
import fuji.fs.native;
import fuji.input;

import db.tools.log;
import db.renderer;
import db.songlibrary;
import db.instrument;
import db.player;
import db.profile;
import db.performance;
import db.sequence;

import db.i.inputdevice;


class Game
{
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

		// TODO: load local settings

		// TODO: scan for dongs (we should cache this data...)
		songLibrary = new SongLibrary;
		songLibrary.Scan();

		// enable buffered input
		MFInput_EnableBufferedInput(true);

		// TODO: auto-detect instruments (controllers, midi/audio devices)
		InputDevice[] inputs = DetectInstruments();

		// HACK: configure a player for each detected input
		int i = 0;
		foreach(input; inputs)
		{
			if(input.instrumentType != InstrumentType.GuitarController && input.instrumentType != InstrumentType.Drums)
				continue;

			Player player = new Player;

			player.profile = new Profile;
			player.profile.name = "Player " ~ to!string(i++);

			player.input.device = input;
			if(input.instrumentType == InstrumentType.GuitarController)
				player.input.part = Part.LeadGuitar;
			else if(input.instrumentType == InstrumentType.Drums)
				player.input.part = Part.Drums;

			players ~= player;
		}

		// HACK: create a performance of the first song in the library
		if(songLibrary.songs.length != 0)
		{
			performance = new Performance(songLibrary.songs[0], players);
			performance.Begin();
		}
	}

	void Deinit()
	{
		renderer.Destroy();
	}

	void Update()
	{
		if(performance)
			performance.Update();
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

		// TODO: Draw the UI
		renderer.SetCurrentLayer(RenderLayers.UI);

		// render debug stuff...
		renderer.SetCurrentLayer(RenderLayers.Debug);
		MFView_Push();

		MFRect rect = MFRect(0, 0, 1920, 1080);
		MFView_SetOrtho(&rect);

		DrawLog();

		MFView_Pop();
	}

	// data
	MFInitParams initParams;

	Renderer renderer;

	SongLibrary songLibrary;

	Player[] players;

	Performance performance;

	// singleton stuff
	static @property Game Instance() { if(instance is null) instance = new Game; return instance; }

	static extern (C) void Static_InitFileSystem()
	{
		instance.InitFileSystem();
	}

	static extern (C) void Static_Init()
	{
		instance.Init();
	}

	static extern (C) void Static_Deinit()
	{
		instance.Deinit();
		instance = null;
	}

	static extern (C) void Static_Update()
	{
		instance.Update();
	}

	static extern (C) void Static_Draw()
	{
		instance.Draw();
	}

private:
	__gshared Game instance;
}
