module db.songlibrary;

import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

public import db.song;
import db.sequence;
import db.tools.midifile;

import std.string;

class SongLibrary
{
	void Scan()
	{
		foreach(file; dirEntries("songs:*", SpanMode.breadth))
		{
			try
			{
				if(file.filename.icmp("song.ini") == 0)
				{
					Song song = LoadFromMidi(file);
					songs ~= song;
				}
				else if(file.filename.endsWith(".chart"))
				{
					// we have a legacy feedback chart
					MFDebug_Log(0, file.filepath);

					// TODO: parse old feedback charts
				}
				else if(file.filename.endsWith(".sm"))
				{
					// TODO: stepmania anyone? :)
				}
				else if(file.filename.endsWith(".dwi"))
				{
					// TODO: how about dance with intensity? :P
				}
			}
			catch
			{
				MFDebug_Warn(2, "Failed to load song: '" ~ file.filepath ~ "'");
			}
		}
	}

	Song LoadFromMidi(DirEntry file)
	{
		import std.range;
		import std.path;

		char[] ini = cast(char[])MFFileSystem_Load(file.filepath);
		scope(exit) MFHeap_Free(ini);

		string path = file.directory ~ "/";

		MFDebug_Log(2, "Loading song: '" ~ file.directory ~ "'");

		MIDIFile midi = new MIDIFile(path ~ "notes.mid");
//		midi.WriteText(path ~ "midi.txt");

		Song song = new Song(midi);
		song.songPath = path;

		// read song.ini
		foreach(l; ini.splitLines)
		{
			l.strip;
			if(l.empty)
				continue;

			if(l[0] == '[' && l[$-1] == ']')
			{
				// we only know about 'song' sections
				assert(l[1..$-1] == "song", "Expected 'song' section");
			}
			else
			{
				ptrdiff_t equals = l.indexOf('=');
				if(equals == -1)
					continue; // not a key-value pair?

				char[] key = l[0..equals].strip.toLower;
				string value = l[equals+1..$].strip.idup;

				switch(key)
				{
					case "name":	song.name = value; break;
					case "artist":	song.artist = value; break;
					case "album":	song.album = value; break;
					case "year":	song.year = value; break;
					case "genre":	song.genre = value; break;
					case "frets":	song.charterName = value; break;
					default:
						// unknown values become arbitrary params
						song.params[key.idup] = value;
						break;
				}
			}
		}

		// search for the music and other stuff...
		foreach(f; dirEntries(path ~ "*", SpanMode.shallow))
		{
			static immutable imageTypes = [ ".png", ".jpg", ".jpeg", ".tga", ".dds", ".bmp" ];
			static immutable musicTypes = [ ".ogg", ".mp3", ".flac", ".wav" ];

			string filename = f.filename.toLower;
			if(std.algorithm.canFind(imageTypes, filename.extension))
			{
				switch(filename.stripExtension)
				{
					case "album":		song.cover = f.filename; break;
					case "background":	song.background = f.filename; break;
					default:
				}
			}
			else if(std.algorithm.canFind(musicTypes, filename.extension))
			{
//				static immutable musicFileNames = [ "preview": MusicFiles.Preview ];

				string filepart = filename.stripExtension;
				if(filepart[] == "rhythm")
				{
					// 'rhythm.ogg' is also be used for bass
					if(song.parts[Part.RhythmGuitar].variations)
						song.musicFiles[MusicFiles.Rhythm] = f.filename;
					else
						song.musicFiles[MusicFiles.Bass] = f.filename;
				}
				else if(filepart in musicFileNames)
					song.musicFiles[musicFileNames[filepart]] = f.filename;
			}
		}

		return song;
	}

	// TODO: database...
	Song[] songs;
}

// HACK: workaround since we can't initialise static AA's
__gshared immutable MusicFiles[string] musicFileNames;
shared static this()
{
	musicFileNames =
	[
		"preview":		MusicFiles.Preview,
		"song":			MusicFiles.Song,
		"song+crowd":	MusicFiles.Vocals,
		"vocals":		MusicFiles.Vocals,
		"crowd":		MusicFiles.Crowd,
		"guitar":		MusicFiles.Guitar,
		"rhythm":		MusicFiles.Rhythm,
		"drums":		MusicFiles.Drums,
		"drums_1":		MusicFiles.Kick,
		"drums_2":		MusicFiles.Snare,
		"drums_3":		MusicFiles.Cymbals,
		"drums_4":		MusicFiles.Toms
	];
}
