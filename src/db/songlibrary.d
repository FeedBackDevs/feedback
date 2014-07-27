module db.songlibrary;

import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

public import db.song;
import db.sequence;
import db.formats.ghrbmidi;
import db.formats.rawmidi;
import db.formats.gtp;
import db.formats.sm;
import db.formats.dwi;
import db.formats.ksf;
import db.formats.bms;

import std.string;
import std.encoding;
import std.range;
import std.path;
import std.exception;
import std.uni;
import std.conv;
import std.algorithm;


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
	struct Source
	{
		void addStream(string filename, Streams type = Streams.Song)
		{
			streams ~= File(type, filename);
		}

		struct File
		{
			Streams type;
			string stream;
		}
		File[] streams;
	}

	bool bLocal;	// if the track is local, or from the archive
	// todo: probably want a link to the archive entry if if one exists...

	string contentPath;

	Song song;

	// audio sources
	Source[] sources;

	// associated data
	string preview;					// short preview clip
	string video;					// background video

	string cover;					// cover image
	string background;				// background image
	string fretboard;				// custom fretboard graphic

	Source* addSource()
	{
		sources ~= Source();
		return &sources[$-1];
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
			.map!(c => c == ' ' ? cast(dchar)'_' : c)									// convert spaces to underscores
			.text;
	}

	// return in the format "band_name-song_name[-suffix]"
	return simplify(artist) ~ "-" ~ simplify(song) ~ (suffix ? "-" ~ simplify(suffix) : null);
}


class SongLibrary
{
	void scan(string path = "songs:")
	{
		string searchPattern = path ~ "*";
		foreach(e; dirEntries(searchPattern, SpanMode.shallow))
		{
			if(e.attributes & (MFFileAttributes.Directory | MFFileAttributes.SymLink))
			{
				scan(e.filepath ~ "/");
			}
			else if(e.filename.extension.icmp(".chart") == 0)
			{
				// load chart file...
			}
		}

		foreach(file; dirEntries(searchPattern, SpanMode.shallow).filter!(e => !(e.attributes & (MFFileAttributes.Directory | MFFileAttributes.SymLink))))
		{
			try
			{
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
					track.song.saveChart(track.contentPath);
					if(track.song.id !in songs)
						songs[track.song.id] = track;
				}
			}
			catch(Exception e)
			{
				MFDebug_Warn(2, "Failed to load '" ~ file.filepath ~ "': " ~ e.msg);
			}
		}
	}

	Track* find(const(char)[] name)
	{
		return name in songs;
	}

	// TODO: database...
	Track[string] songs;

	// recognised files...
	struct File
	{
		uint lastTouched;
		Track* track;
	}
	File[string] fileAssociations;
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
