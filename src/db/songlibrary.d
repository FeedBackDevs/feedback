module db.songlibrary;

import std.string;

import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import db.song;
import db.tools.midifile;

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
			immutable imageTypes = [ ".png", ".jpg", ".jpeg", ".tga", ".dds", ".bmp" ];
			immutable musicTypes = [ ".ogg", ".mp3", ".flac", ".wav" ];

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
				switch(filename.stripExtension)
				{
					case "preview":		song.previewFilename = f.filename; break;
					case "song":		song.songFilename = f.filename; break;
					case "song+crowd":	song.songWithCrowdFilename = f.filename; break;
					case "vocals":		song.vocalsFilename = f.filename; break;
					case "crowd":		song.crowdFilename = f.filename; break;
					case "guitar":		song.guitarFilename = f.filename; break;
					case "rhythm":		song.bassFilename = f.filename; break;
					case "drums":		song.drumsFilename = f.filename; break;
					case "drums_1":		song.kickFilename = f.filename; break;
					case "drums_2":		song.snareFilename = f.filename; break;
					case "drums_3":		song.cymbalsFilename = f.filename; break;
					case "drums_4":		song.tomsFilename = f.filename; break;
					default:
				}
			}
		}

		return song;
	}

	// TODO: database...
	Song[] songs;
}
