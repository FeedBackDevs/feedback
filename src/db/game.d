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
import db.sequence;
import db.instrument;
import db.player;
import db.profile;

import db.i.inputdevice;
import db.i.notetrack;
import db.i.scorekeeper;

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

		// TODO: scan for dongs (we should cache this data...)
		songLibrary = new SongLibrary;
		songLibrary.Scan();

		// TODO: auto-detect instruments (controllers, midi/audio devices)
		InputDevice[] inputs = DetectInstruments();

		// HACK: configure a player for each detected input
		int i = 0;
		foreach(input; inputs)
		{
			if(input.instrumentType != InstrumentType.GuitarController || input.instrumentType != InstrumentType.Drums)
				continue;

			Player player = new Player;
			players ~= player;

			player.profile = new Profile;
			player.profile.name = "Player " ~ to!string(i++);

			player.input.device = input;
			if(input.instrumentType != InstrumentType.GuitarController)
				player.input.part = Part.LeadGuitar;
			else
				player.input.part = Part.Drums;
		}

		// HACK: pick the first song and play it as a test
		if(songLibrary.songs != null)
		{
			currentSong = songLibrary.songs[0];
			currentSong.Prepare();

			currentSong.Pause(false);
		}

		// create and arrange the performers for 'currentSong'
		// Note: Players whose parts are unavailable in the song will not have performers created
		performers = null;
		foreach(p; players)
		{
			if(currentSong.IsPartPresent(p.input.part))
			{
				// TODO: create a performer for the player...
				// Note: note track should be chosen accorting to the instrument type, and player preference for theme/style (GH/RB/Bemani?)
				Performer performer;
				performer.player = p;
				performer.sequence = currentSong.variations[p.input.part][0].difficulties.back;
//				performer.noteTrack = new THE KIND THAT MATCHES;
//				performer.scoreKeeper = new ScoreKeeper(performer.sequence, p.input.device);
				performers ~= performer;
			}
		}

		// TODO: arrange the performers to best utilise the available screen space...
		//... this is kinda hard!
	}

	void Deinit()
	{
		MFRenderer_Destroy(pRenderer);
		MFStateBlock_Destroy(pDefaultStates);
	}

	void Update()
	{
		// TODO: update the performers...
	}

	void Draw()
	{
		// TODO: draw the background

		// TODO: draw the performers

		// TODO: Draw the UI
	}

	// data
	MFInitParams initParams;

	SongLibrary songLibrary;

	Player[] players;

	Song currentSong;

	// a performer is an active player/'performer'.
	struct Performer
	{
		MFRect screenSpace;
		Player player;
		Sequence sequence;
		NoteTrack noteTrack;
		ScoreKeeper scoreKeeper;
	}

	Performer performers[];

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
