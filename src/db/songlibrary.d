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
					Song song = LoadGHRBMidi(file);
					songs ~= song;
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
						Song song = LoadSM(file);
						songs ~= song;
						break;
					}
					case ".ksf":
					{
						// kick is up step file (5-panel 'pump it up' steps)
						Song song = LoadKSF(file, this);
						if(song) // ksf files may update an existing song
							songs ~= song;
						break;
					}
					case ".dwi":
					{
						// danci with intensity step file
						Song song = LoadDWI(file);
						songs ~= song;
						break;
					}
					case ".bme":
					case ".bms":
					{
						// beatmania keys
//						Song song = LoadBMS(file);
//						songs ~= song;
						break;
					}
					case ".gtp":
					case ".gp3":
					case ".gp4":
					case ".gp5":
					case ".gpx":
					{
						Song song = LoadGuitarPro(file);
						songs ~= song;
						break;
					}
					case ".mid":
					{
						if(file.filename.icmp("notes.mid") == 0)
							break;
						// raw midi file
						Song song = LoadRawMidi(file);
						songs ~= song;
						break;
					}
					default:
				}
			}
			catch
			{
				MFDebug_Warn(2, "Failed to load song: '" ~ file.filepath ~ "'");
			}
		}
	}

	Song Find(const(char)[] name)
	{
		foreach(s; songs)
		{
			if(s.id[] == name || s.name[] == name)
				return s;
		}
		return null;
	}

	// TODO: database...
	Song[] songs;
}
