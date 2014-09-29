module db.songlibrary;

import fuji.dbg;
import fuji.heap;
import fuji.filesystem;
import fuji.system;
import fuji.sound;
import fuji.material;

public import db.song;
import db.sequence;
import db.formats.ghrbmidi;
import db.formats.rawmidi;
import db.formats.gtp;
import db.formats.sm;
import db.formats.dwi;
import db.formats.ksf;
import db.formats.bms;
import db.tools.filetypes;
import db.tools.enumkvp;

import luad.base;

import std.string;
import std.encoding;
import std.range;
import std.path;
import std.exception;
import std.uni;
import std.conv;
import std.algorithm;
import std.xml;


// music files (many of these may or may not be available for different songs)
enum Streams
{
	Song,			// the backing track (often includes vocals)
	SongWithCrowd,	// backing track with crowd sing-along (sing-along, for star-power mode/etc.)
	Vocals,			// discreet vocal track
	Crowd,			// crowd-sing-along, for star-power/etc.
	Guitar,
	Rhythm,
	Bass,
	Keys,
	Drums,			// drums mixed to a single track

	// paths to music for split drums (guitar hero world tour songs split the drums into separate tracks)
	Kick,
	Snare,
	Cymbals,		// all cymbals
	Toms,			// all toms

	Count
}


struct Track
{
	@property Song song()
	{
		if(!_song)
			_song = new Song(localChart);

		return _song;
	}

	@property string preview() { return _preview; }
	@property string cover() { return coverImage; }

	@property string path() { return song.songPath; }

	@property string id() { return song.id; }
	@property string name() { return song.name; }
	@property string variant() { return song.variant; }
	@property string subtitle() { return song.subtitle; }
	@property string artist() { return song.artist; }
	@property string album() { return song.album; }
	@property string year() { return song.year; }
	@property string packageName() { return song.packageName; }
	@property string charterName() { return song.charterName; }

	// TODO: tags should be split into an array
//	@property string tags() { return song.tags; }
	@property string genre() { return song.genre; }
	@property string mediaType() { return song.mediaType; }

	// TODO: is AA
//	@property string params() { return song.params; }

	@property int resolution() { return song.resolution; }
	@property long startOffset() { return song.startOffset; }


	// TODO: add something to fetch information about the streams...

	void pause(bool bPause)
	{
		foreach(s; streams)
			if(s)
				MFSound_PauseStream(s, bPause);
	}

	void seek(float offsetInSeconds)
	{
		foreach(s; streams)
			if(s)
				MFSound_SeekStream(s, offsetInSeconds);
	}

	void setVolume(Part part, float volume)
	{
		// TODO: figure how parts map to playing streams
	}

	void setPan(Part part, float pan)
	{
		// TODO: figure how parts map to playing streams
	}

@noscript:
	struct Source
	{
		struct File
		{
			Streams type;
			string stream;
		}

		File[] streams;

		void addStream(string filename, Streams type = Streams.Song) { streams ~= File(type, filename); }
	}

	// TODO: link to archive entry if the chart comes from the archive...
//	ArchiveEntry archiveEntry;		// reference to the archive entry, if the song is present in the archive...

	string localChart;				// path to local chart file

	// associated data
	string _preview;				// short preview clip
	string video;					// background video

	string coverImage;				// cover image
	string background;				// background image
	string fretboard;				// custom fretboard graphic

	// audio sources
	Source[] sources;

	// runtime data
	Song _song;

	MFAudioStream*[Streams.Count] streams;
	MFVoice*[Streams.Count] voices;

	Material _cover;
	Material _background;
	Material _fretboard;

	// methods...
	~this()
	{
		release();
	}

	Source* addSource()
	{
		sources ~= Source();
		return &sources[$-1];
	}

	void prepare()
	{
		song.prepare();

		// load audio streams...

		// load song data...

		// TODO: choose a source
		Source* source = &sources[0];

		// prepare the music streams
		foreach(ref s; source.streams)
		{
			streams[s.type] = MFSound_CreateStream(s.stream.toStringz, MFAudioStreamFlags.QueryLength | MFAudioStreamFlags.AllowSeeking);
			MFSound_PlayStream(streams[s.type], MFPlayFlags.BeginPaused);

			voices[s.type] = MFSound_GetStreamVoice(streams[s.type]);
//			MFSound_SetPlaybackRate(voices[i], 1.0f); // TODO: we can use this to speed/slow the song...
		}

		// load data...
		if(coverImage)
			_cover = Material(coverImage);
		if(background)
			_background = Material(background);
		if(fretboard)
			_fretboard = Material(fretboard);
	}

	void release()
	{
		foreach(ref s; streams)
		{
			if(s)
			{
				MFSound_DestroyStream(s);
				s = null;
			}
		}

		_cover = null;
		_background = null;
		_fretboard = null;
	}
}

class SongLibrary
{
	this(string filename = null)
	{
		load(filename ? filename : "system:cache/library.xml");
	}

	void load(string filename)
	{
		try
		{
			string file = MFFileSystem_LoadText(filename).assumeUnique;
			if(!file)
				return;

			// parse xml
			auto xml = new DocumentParser(file);

			xml.onEndTag["lastScan"] = (in Element e) { lastScan.ticks		= to!ulong(e.text()); };

			xml.onStartTag["tracks"] = (ElementParser xml)
			{
				xml.onStartTag["track"] = (ElementParser xml)
				{
					Track track;
					string id = xml.tag.attr["id"];

					xml.onEndTag["localChart"]	= (in Element e) { track.localChart		= e.text(); };
					xml.onEndTag["preview"]		= (in Element e) { track._preview		= e.text(); };
					xml.onEndTag["video"]		= (in Element e) { track.video			= e.text(); };
					xml.onEndTag["cover"]		= (in Element e) { track.coverImage		= e.text(); };
					xml.onEndTag["background"]	= (in Element e) { track.background		= e.text(); };
					xml.onEndTag["fretboard"]	= (in Element e) { track.fretboard		= e.text(); };

					xml.onStartTag["sources"] = (ElementParser xml)
					{
						xml.onStartTag["source"] = (ElementParser xml)
						{
							Track.Source* src = track.addSource();
							xml.onEndTag["stream"]	= (in Element e)
							{
								src.addStream(e.text(), getEnumValue!Streams(e.tag.attr["type"]));
							};
							xml.parse();
						};
						xml.parse();
					};
					xml.parse();

					library[id] = track;
				};
				xml.parse();
			};
			xml.parse();
		}
		catch(Exception e)
		{
			MFDebug_Warn(2, "Couldn't load settings: " ~ e.msg);
		}
	}

	void save()
	{
		auto doc = new Document(new Tag("library"));

		doc ~= new Element("lastScan", to!string(lastScan.ticks));

		auto tracks = new Element("tracks");
		foreach(id, ref track; library)
		{
			auto t = new Element("track");
			t.tag.attr["id"] = id;

			if(track.localChart)	t ~= new Element("localChart", track.localChart);

			if(track._preview)		t ~= new Element("preview", track._preview);
			if(track.video)			t ~= new Element("video", track.video);

			if(track.coverImage)	t ~= new Element("cover", track.coverImage);
			if(track.background)	t ~= new Element("background", track.background);
			if(track.fretboard)		t ~= new Element("fretboard", track.fretboard);

			auto srcs = new Element("sources");
			foreach(ref s; track.sources)
			{
				auto src = new Element("source");
				foreach(ref stream; s.streams)
				{
					auto str = new Element("stream", stream.stream);
					str.tag.attr["type"] = getEnumFromValue(stream.type);
					src ~= str;
				}
				srcs ~= src;
			}
			t ~= srcs;
			tracks ~= t;
		}
		doc ~= tracks;

		string xml = join(doc.pretty(2),"\n");
		MFFileSystem_SaveText("system:cache/library.xml", xml);
	}

	void scan()
	{
		scanPath("songs:");

		MFSystemTime systime;
		MFSystem_SystemTime(&systime);
		MFSystem_SystemTimeToFileTime(&systime, &lastScan);

		save();
	}

	Track* find(const(char)[] name)
	{
		return name in library;
	}

	@property string[] songs()
	{
		return library.keys;
	}

private:
	// local database
	Track[string] library;

	MFFileTime lastScan;

	void scanPath(string path)
	{
		string searchPattern = path ~ "*";

		// first we'll do a pass recursing into directories, and trying to load .chart files
		// this is because other format songs that were converted will have had a .chart file saved which we prefer to load
		foreach(e; dirEntries(searchPattern, SpanMode.shallow))
		{
			if(e.attributes & (MFFileAttributes.Directory | MFFileAttributes.SymLink))
			{
				scanPath(e.filepath ~ "/");
			}
			else if(e.filename.extension.icmp(".chart") == 0 && e.writeTime > lastScan)
			{
				Track track;
				track._song = new Song(e.filepath);

				// search for the music and other stuff...
				string songName = e.filename.stripExtension.toLower;
				foreach(f; dirEntries(e.directory ~ "/*", SpanMode.shallow))
				{
					string filename = f.filename.toLower;
					string fn = filename.stripExtension;
					if(isImageFile(filename))
					{
						if(fn[] == songName)
							track.coverImage = f.filename;
						else if(fn[] == songName ~ "-bg")
							track.background = f.filename;
					}
					else if(isAudioFile(filename))
					{
						if(fn[] == songName)
							track.addSource().addStream(f.filename);
						if(fn[] == songName ~ "-intro")
							track._preview = f.filename;
					}
					else if(isVideoFile(filename))
					{
						if(fn[] == songName)
							track.video = f.filename;
					}
				}

				library[track._song.id] = track;
			}
		}

		// search for other formats and try and load + convert them
		foreach(file; dirEntries(searchPattern, SpanMode.shallow).filter!(e => !(e.attributes & (MFFileAttributes.Directory | MFFileAttributes.SymLink)) && e.writeTime > lastScan))
		{
			try
			{
				string dir = file.directory ~ "/";

				Track track;
				bool addTrack;

				if(file.filename.icmp("song.ini") == 0)
				{
					if(LoadGHRBMidi(&track, file))
						addTrack = true;
				}
				else switch(file.filename.extension.toLower)
				{
					case ".chart":
					{
						// we have a legacy feedback chart
						MFDebug_Log(0, file.filepath);

						// TODO: parse old feedback charts
						break;
					}
					case ".sm":
					{
						// stepmania step file
						if(LoadSM(&track, file))
							addTrack = true;
						break;
					}
					case ".ksf":
					{
						// kick is up step file (5-panel 'pump it up' steps)
						if(LoadKSF(&track, file, this))
							addTrack = true;
						break;
					}
					case ".dwi":
					{
						// danci with intensity step file
						if(LoadDWI(&track, file))
							addTrack = true;
						break;
					}
					case ".bme":
					case ".bms":
					{
						// beatmania keys
//						if(LoadBMS(file))
//							addTrack = true;
						break;
					}
					case ".gtp":
					case ".gp3":
					case ".gp4":
					case ".gp5":
					case ".gpx":
					{
						if(LoadGuitarPro(&track, file))
							addTrack = true;
						break;
					}
					case ".mid":
					{
						if(file.filename.icmp("notes.mid") == 0)
							break;
						// raw midi file
						if(LoadRawMidi(&track, file))
							addTrack = true;
						break;
					}
					default:
				}

				if(addTrack)
				{
					// write out a .chart for the converted song
					track._song.saveChart(dir);
					track.localChart = track._song.songPath;

					if(track._song.id !in library)
						library[track._song.id] = track;
				}
			}
			catch(Exception e)
			{
				MFDebug_Warn(2, "Failed to load '" ~ file.filepath ~ "': " ~ e.msg);
			}
		}
	}
}

string archiveName(string artist, string song, string suffix = null)
{
	static string simplify(string s)
	{
		int depth;
		dchar prev;
		bool filter(dchar c)
		{
			if(c == '(' || c == '[')
				++depth;
			if(c == ')' || c == ']')
			{
				--depth;
				return false;
			}
			bool rep = c == ' ' && prev == ' ';
			prev = c;
			return depth == 0 && !rep;
		}

		auto marks = unicode("Nonspacing_Mark");
		string[dchar] transTable = ['&' : " and "];

		return s.translate(transTable)										// translate & -> and
			.normalize!NFKD													// separate accents from base characters
			.map!(c => "\t_.-!?".canFind(c) ? cast(dchar)' ' : c.toLower)	// convert unwanted chars to spaces, and letters to lowercase
			.filter!(c => !marks[c] && !"'\"".canFind(c) && filter(c))		// strip accents, select noise cahracters, and bracketed content
			.text.strip														// strip leading and trailing whitespace
			.map!(c => c == ' ' ? cast(dchar)'_' : c)						// convert spaces to underscores
			.text;
	}

	// return in the format "band_name-song_name[-suffix]"
	return simplify(artist) ~ "-" ~ simplify(song) ~ (suffix ? "-" ~ simplify(suffix) : null);
}


// HACK: workaround since we can't initialise static AA's
__gshared immutable Streams[string] musicFileNames;
shared static this()
{
	musicFileNames =
	[
		"song":			Streams.Song,
		"song+crowd":	Streams.Vocals,
		"vocals":		Streams.Vocals,
		"crowd":		Streams.Crowd,
		"guitar":		Streams.Guitar,
		"rhythm":		Streams.Rhythm,
		"drums":		Streams.Drums,
		"drums_1":		Streams.Kick,
		"drums_2":		Streams.Snare,
		"drums_3":		Streams.Cymbals,
		"drums_4":		Streams.Toms
	];
}
