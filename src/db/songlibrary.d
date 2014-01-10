module db.songlibrary;

import std.string;
import std.path;

import fuji.filesystem;
import fuji.dbg;

import db.song;
import db.tools.midifile;

class SongLibrary
{
	void Scan()
	{
		foreach(file; dirEntries("songs:*", SpanMode.breadth))
		{
			if(file.filename.icmp("song.ini") == 0)
			{
				// TODO: parse midi based songs...
				try
				{
					MIDIFile midi = new MIDIFile(file.directory ~ "/notes.mid");

					Song song = new Song(midi);

					// search for all the music and other stuff...
					if(MFFileSystem_Exists(file.directory ~ "/album.png"))
						song.cover = "album.png";

					songs ~= song;
				}
				catch
				{
					// notify the user of bad data?
					assert(false, "Bad data!");
				}
			}
			else if(file.filename.endsWith(".chart"))
			{
				// we have a legacy feedback chart
				MFDebug_Log(0, file.filepath);

				// TODO: parse old feedback charts
			}
		}
	}

	// TODO: database...
	Song[] songs;
}
