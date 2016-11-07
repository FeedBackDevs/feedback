module db.library;

// TODO: remove like, all these imports!
import fuji.dbg;
import fuji.heap;
import fuji.filesystem;
import fuji.system;
import fuji.sound;
import fuji.material;

public import db.chart : Chart;

import db.formats.ghrbmidi;
import db.formats.rawmidi;
import db.formats.gtp;
import db.formats.sm;
import db.formats.dwi;
import db.formats.ksf;
import db.formats.bms;
import db.tools.filetypes;
import db.tools.enumkvp;

import luad.base : noscript;

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


struct Song
{
	@property Chart chart()
	{
		if (!_chart)
			_chart = new Chart(localChart);

		return _chart;
	}

	@property string preview() { return _preview; }
	@property string cover() { return coverImage; }

	@property string path() { return chart.songPath; }

	@property string id() { return chart.id; }
	@property string name() { return chart.name; }
	@property string variant() { return chart.variant; }
	@property string subtitle() { return chart.subtitle; }
	@property string artist() { return chart.artist; }
	@property string album() { return chart.album; }
	@property string year() { return chart.year; }
	@property string packageName() { return chart.packageName; }
	@property string charterName() { return chart.charterName; }

	// TODO: tags should be split into an array
//	@property string tags() { return song.tags; }
	@property string genre() { return chart.genre; }
	@property string mediaType() { return chart.mediaType; }

	// TODO: is AA
//	@property string params() { return song.params; }

	@property int resolution() { return chart.resolution; }
	@property long startOffset() { return chart.startOffset; }


	// TODO: add something to fetch information about the streams...

	void pause(bool bPause)
	{
		foreach (s; streams)
			if (s)
				MFSound_PauseStream(s, bPause);
	}

	void seek(float offsetInSeconds)
	{
		foreach (s; streams)
			if (s)
				MFSound_SeekStream(s, offsetInSeconds);
	}

	void setVolume(string part, float volume)
	{
		// TODO: figure how parts map to playing streams
	}

	void setPan(string part, float pan)
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
	Chart _chart;

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
		chart.prepare();

		// load audio streams...

		// load song data...

		// TODO: choose a source
		Source* source = &sources[0];

		// prepare the music streams
		foreach (ref s; source.streams)
		{
			streams[s.type] = MFSound_CreateStream(s.stream.toStringz, MFAudioStreamFlags.QueryLength | MFAudioStreamFlags.AllowSeeking);
			MFSound_PlayStream(streams[s.type], MFPlayFlags.BeginPaused);

			voices[s.type] = MFSound_GetStreamVoice(streams[s.type]);
//			MFSound_SetPlaybackRate(voices[i], 1.0f); // TODO: we can use this to speed/slow the song...
		}

		// load data...
		if (coverImage)
			_cover = Material(coverImage);
		if (background)
			_background = Material(background);
		if (fretboard)
			_fretboard = Material(fretboard);
	}

	void release()
	{
		foreach (ref s; streams)
		{
			if (s)
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
			if (!file)
				return;

			// parse xml
			auto xml = new DocumentParser(file);

			xml.onEndTag["lastScan"] = (in Element e) { lastScan.ticks		= to!ulong(e.text()); };

			xml.onStartTag["songs"] = (ElementParser xml)
			{
				xml.onStartTag["song"] = (ElementParser xml)
				{
					Song song;
					string id = xml.tag.attr["id"];

					xml.onEndTag["localChart"]	= (in Element e) { song.localChart		= e.text(); };
					xml.onEndTag["preview"]		= (in Element e) { song._preview		= e.text(); };
					xml.onEndTag["video"]		= (in Element e) { song.video			= e.text(); };
					xml.onEndTag["cover"]		= (in Element e) { song.coverImage		= e.text(); };
					xml.onEndTag["background"]	= (in Element e) { song.background		= e.text(); };
					xml.onEndTag["fretboard"]	= (in Element e) { song.fretboard		= e.text(); };

					xml.onStartTag["sources"] = (ElementParser xml)
					{
						xml.onStartTag["source"] = (ElementParser xml)
						{
							Song.Source* src = song.addSource();
							xml.onEndTag["stream"]	= (in Element e)
							{
								src.addStream(e.text(), getEnumValue!Streams(e.tag.attr["type"]));
							};
							xml.parse();
						};
						xml.parse();
					};
					xml.parse();

					library[id] = song;
				};
				xml.parse();
			};
			xml.parse();
		}
		catch (Exception e)
		{
			MFDebug_Warn(2, "Couldn't load settings: " ~ e.msg);
		}
	}

	void save()
	{
		auto doc = new Document(new Tag("library"));

		doc ~= new Element("lastScan", to!string(lastScan.ticks));

		auto songs = new Element("songs");
		foreach (id, ref song; library)
		{
			auto s = new Element("song");
			s.tag.attr["id"] = id;

			if (song.localChart)	s ~= new Element("localChart", song.localChart);

			if (song._preview)	s ~= new Element("preview", song._preview);
			if (song.video)		s ~= new Element("video", song.video);

			if (song.coverImage)	s ~= new Element("cover", song.coverImage);
			if (song.background)	s ~= new Element("background", song.background);
			if (song.fretboard)	s ~= new Element("fretboard", song.fretboard);

			auto srcs = new Element("sources");
			foreach (ref src; song.sources)
			{
				auto source = new Element("source");
				foreach (ref stream; src.streams)
				{
					auto str = new Element("stream", stream.stream);
					str.tag.attr["type"] = getEnumFromValue(stream.type);
					source ~= str;
				}
				srcs ~= source;
			}
			s ~= srcs;
			songs ~= s;
		}
		doc ~= songs;

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

	Song* find(const(char)[] name)
	{
		return name in library;
	}

	@property string[] songs()
	{
		return library.keys;
	}

private:
	// local database
	Song[string] library;

	MFFileTime lastScan;

	void scanPath(string path)
	{
		string searchPattern = path ~ "*";

		// first we'll do a pass recursing into directories, and trying to load .chart files
		// this is because other format songs that were converted will have had a .chart file saved which we prefer to load
		foreach (e; dirEntries(searchPattern, SpanMode.shallow))
		{
			if (e.attributes & (MFFileAttributes.Directory | MFFileAttributes.SymLink))
			{
				scanPath(e.filepath ~ "/");
			}
			else if (e.filename.extension.icmp(".chart") == 0 && (e.writeTime > lastScan || e.createTime > lastScan))
			{
				Song song;
				song._chart = new Chart(e.filepath);

				// search for the music and other stuff...
				string songName = e.filename.stripExtension.toLower;
				foreach (f; dirEntries(e.directory ~ "/*", SpanMode.shallow))
				{
					string filename = f.filename.toLower;
					string fn = filename.stripExtension;
					if (isImageFile(filename))
					{
						if (fn[] == songName)
							song.coverImage = f.filename;
						else if (fn[] == songName ~ "-bg")
							song.background = f.filename;
					}
					else if (isAudioFile(filename))
					{
						if (fn[] == songName)
							song.addSource().addStream(f.filename);
						if (fn[] == songName ~ "-intro")
							song._preview = f.filename;
					}
					else if (isVideoFile(filename))
					{
						if (fn[] == songName)
							song.video = f.filename;
					}
				}

				library[song._chart.id] = song;
			}
		}

		// search for other formats and try and load + convert them
		foreach (file; dirEntries(searchPattern, SpanMode.shallow).filter!(e => !(e.attributes & (MFFileAttributes.Directory | MFFileAttributes.SymLink)) && (e.writeTime > lastScan || e.createTime > lastScan)))
		{
			try
			{
				string dir = file.directory ~ "/";

				Song song;
				bool addTrack;

				if (file.filename.icmp("song.ini") == 0)
				{
					if (LoadGHRBMidi(&song, file))
						addTrack = true;
				}
				else switch (file.filename.extension.toLower)
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
						if (LoadSM(&song, file))
							addTrack = true;
						break;
					}
					case ".ksf":
					{
						// kick is up step file (5-panel 'pump it up' steps)
						if (LoadKSF(&song, file, this))
							addTrack = true;
						break;
					}
					case ".dwi":
					{
						// danci with intensity step file
						if (LoadDWI(&song, file))
							addTrack = true;
						break;
					}
					case ".bme":
					case ".bms":
					{
						// beatmania keys
//						if (LoadBMS(file))
//							addTrack = true;
						break;
					}
					case ".gtp":
					case ".gp3":
					case ".gp4":
					case ".gp5":
					case ".gpx":
					{
						if (LoadGuitarPro(&song, file))
							addTrack = true;
						break;
					}
					case ".mid":
					{
						if (file.filename.icmp("notes.mid") == 0)
							break;
						// raw midi file
						if (LoadRawMidi(&song, file))
							addTrack = true;
						break;
					}
					default:
				}

				if (addTrack)
				{
					// write out a .chart for the converted song
					song._chart.saveChart(dir);
					song.localChart = song._chart.songPath;

					if (song._chart.id !in library)
						library[song._chart.id] = song;
				}
			}
			catch (Exception e)
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
			if (c == '(' || c == '[')
				++depth;
			if (c == ')' || c == ']')
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
