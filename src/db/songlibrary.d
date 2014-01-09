module db.songlibrary;

import std.string;
import std.path;

import fuji.filesystem;

import db.song;

class SongLibrary
{
	void Scan()
	{
		// TODO: scan for songs

		foreach(file; dirEntries("songs:*", SpanMode.breadth))
		{
			if(file.name.endsWith(".chart"))
			{
				fuji.dbg.MFDebug_Log(0, file.name.toStringz);

				// TODO: load the song details, add it to the database
			}
		}
	}

	// TODO: database...
	Song[] songs;
}
