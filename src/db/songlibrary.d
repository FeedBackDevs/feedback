module db.songlibrary;

import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

public import db.song;
import db.sequence;
import db.tools.midifile;

import std.string;
import std.encoding;
import std.range;
import std.path;
import std.exception;

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
				else if(file.filename.endsWith(".ksf"))
				{
					// kick is up step file (5-panel 'pump it up' steps)
//					Song song = LoadFromKSF(file);
//					songs ~= song;
				}
				else if(file.filename.endsWith(".dwi"))
				{
					// danci with intensity step file
					Song song = LoadFromDWI(file);
					songs ~= song;
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
		void[] ini = MFFileSystem_Load(file.filepath);
		scope(exit) MFHeap_Free(ini);

		string path = file.directory ~ "/";

		MFDebug_Log(2, "Loading song: '" ~ file.directory ~ "'");

		MIDIFile midi = new MIDIFile(path ~ "notes.mid");
//		midi.WriteText(path ~ "midi.txt");

		Song song = new Song;
		song.songPath = path;

		// read song.ini
		string text;
		transcode(cast(Windows1252String)ini, text);

		foreach(l; text.splitLines)
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

				string key = l[0..equals].strip.toLower;
				string value = l[equals+1..$].strip;

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
						song.params[key] = value;
						break;
				}
			}
		}

		// load the midi
		song.LoadMidi(midi);

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

	Song LoadFromDWI(DirEntry file)
	{
		const(char)[] dwi = cast(const(char)[])enforce(MFFileSystem_Load(file.filepath), "");
		scope(exit) MFHeap_Free(cast(void[])dwi);

		string path = file.directory ~ "/";

		MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

		Song song = new Song;
		song.songPath = path;
		song.id = file.filename.stripExtension;
		song.name = song.id;

		// search for the music and other stuff...
		string songName = file.filename.stripExtension.toLower;
		foreach(f; dirEntries(path ~ "*", SpanMode.shallow))
		{
			static immutable imageTypes = [ ".png", ".jpg", ".jpeg", ".tga", ".dds", ".bmp" ];
			static immutable musicTypes = [ ".ogg", ".mp3", ".flac", ".wav" ];

			string filename = f.filename.toLower;
			string ext = filename.extension;
			string fn = filename.stripExtension;
			if(std.algorithm.canFind(imageTypes, ext))
			{
				if(fn[] == songName)
					song.cover = f.filename;
				else if(fn[] == songName ~ "-bg")
					song.background = f.filename;
			}
			else if(std.algorithm.canFind(musicTypes, ext))
			{
				if(fn[] == songName)
					song.musicFiles[MusicFiles.Song] = f.filename;
			}
			else if(filename[] == songName ~ ".lrc")
			{
				// load lyrics into vocal track?
				// move this into the DWI loader?
			}
		}

		// load the midi
		song.LoadDWI(dwi);

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
