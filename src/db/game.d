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

import std.xml;
import std.file;

struct Settings
{
	void Load()
	{
		try
		{
			string s = readText("settings.xml");

			// parse xml
			auto xml = new DocumentParser(s);
			xml.onEndTag["videoDriver"]			= (in Element e) { videoDriver			= to!int(e.text()); };
			xml.onEndTag["audioDriver"]			= (in Element e) { audioDriver			= to!int(e.text()); };
			xml.onEndTag["audioLatency"]		= (in Element e) { audioLatency			= to!long(e.text()); };
			xml.onEndTag["videoLatency"]		= (in Element e) { videoLatency			= to!long(e.text()); };
			xml.onEndTag["controllerLatency"]	= (in Element e) { controllerLatency	= to!long(e.text()); };
			xml.onEndTag["midiLatency"]			= (in Element e) { midiLatency			= to!long(e.text()); };
			xml.onEndTag["micLatency"]			= (in Element e) { micLatency			= to!long(e.text()); };

			xml.onStartTag["devices"] = (ElementParser xml)
			{
				xml.onStartTag["device"] = (ElementParser xml)
				{
					Device device;
					//xml.tag.attr["id"];

					xml.onEndTag["latency"] = (in Element e) { device.latency = to!int(e.text()); };

					xml.parse();

					devices ~= device;
				};
				xml.parse();
			};
			xml.parse();
		}
		catch
		{
		}
	}

	void Save()
	{
		auto doc = new Document(new Tag("settings"));

		doc ~= new Element("videoDriver", to!string(videoDriver));
		doc ~= new Element("audioDriver", to!string(audioDriver));
		doc ~= new Element("audioLatency", to!string(audioLatency));
		doc ~= new Element("videoLatency", to!string(videoLatency));
		doc ~= new Element("controllerLatency", to!string(controllerLatency));
		doc ~= new Element("midiLatency", to!string(midiLatency));
		doc ~= new Element("micLatency", to!string(micLatency));

		auto devs = new Element("devices");
		foreach(device; devices)
		{
			auto dev = new Element("Device");
//			dev.tag.attr["id"] = book.id;

			dev ~= new Element("latency", to!string(device.latency));

			devs ~= dev;
		}
		doc ~= devs;

		string xml = join(doc.pretty(3),"\n");
		write("settings.xml", xml);
	}

	int videoDriver;
	int audioDriver;

	long audioLatency;
	long videoLatency;
	long controllerLatency;
	long midiLatency;
	long micLatency;

	struct Device
	{
		// device type
		// controller/midi/audio

		long latency;
	}

	Device[] devices;
}

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

	// singleton stuff
	static @property Game Instance() { if(instance is null) instance = new Game; return instance; }

	static extern (C) void Static_InitFileSystem() nothrow
	{
		try
		{
			instance.InitFileSystem();
		}
		catch
		{
			//...?
		}
	}

	static extern (C) void Static_Init() nothrow
	{
		try
		{
			instance.Init();
		}
		catch
		{
			//...?
		}
	}

	static extern (C) void Static_Deinit() nothrow
	{
		try
		{
			instance.Deinit();
			instance = null;
		}
		catch
		{
			//...?
		}
	}

	static extern (C) void Static_Update() nothrow
	{
		try
		{
			instance.Update();
		}
		catch
		{
			//...?
		}
	}

	static extern (C) void Static_Draw() nothrow
	{
		try
		{
			instance.Draw();
		}
		catch
		{
			//...?
		}
	}

private:
	__gshared Game instance;
}
