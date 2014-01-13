module db.game;

import fuji.fuji;
import fuji.system;
import fuji.filesystem;
import fuji.fs.native;

import fuji.render;
import fuji.renderstate;
import fuji.material;
import fuji.view;
import fuji.matrix;

import db.songlibrary;
import db.player;
import db.instrument;

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
		pDefaultStates = MFStateBlock_CreateDefault();

		// create the renderer with a single layer that clears before rendering
		MFRenderLayerDescription layers[] = [
			MFRenderLayerDescription("background"),
			MFRenderLayerDescription("game"),
			MFRenderLayerDescription("ui"),
			MFRenderLayerDescription("menu")
		];

		pRenderer = MFRenderer_Create(layers, pDefaultStates, null);
		MFRenderer_SetCurrent(pRenderer);

		MFRenderLayer *pLayer = MFRenderer_GetLayer(pRenderer, 0);
		MFVector clearColour = MFVector(0.0f, 0.0f, 0.2f, 1.0f);
		MFRenderLayer_SetClear(pLayer, MFRenderClearFlags.All, clearColour);

		MFRenderLayerSet layerSet;
		layerSet.pSolidLayer = pLayer;
		MFRenderer_SetRenderLayerSet(pRenderer, &layerSet);

		// TODO: the following stuff should all be asynchronous with a loading screen:

		// TODO: load local settings

		// TODO: auto-detect instruments (controllers, midi/audio devices)
		DetectInstruments();

		// TODO: scan for dongs (we should cache this data...)
		songLibrary = new SongLibrary;
		songLibrary.Scan();


		foreach(s; songLibrary.songs)
			MFDebug_Log(2, s.songPath ~ s.name ~ s.artist);

		// HACK: pick the first song and play it as a test
		if(songLibrary.songs != null)
		{
			currentSong = songLibrary.songs[0];
			currentSong.Prepare();

			currentSong.Pause(false);
		}
	}

	void Deinit()
	{
		MFRenderer_Destroy(pRenderer);
		MFStateBlock_Destroy(pDefaultStates);
	}

	void Update()
	{
	}

	void Draw()
	{
	}

	// data
	MFInitParams initParams;

	SongLibrary songLibrary;

	Player[] players;

	Song currentSong;


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
	MFRenderer *pRenderer;
	MFStateBlock *pDefaultStates;
}
