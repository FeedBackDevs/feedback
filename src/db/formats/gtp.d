module db.formats.gtp;

import fuji.filesystem;
import fuji.dbg;

import db.song;
import db.sequence;
import db.formats.parsers.midifile;
import db.formats.parsers.guitarprofile;

Song LoadGuitarPro(DirEntry file)
{
	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

	Song song = new Song;
	song.songPath = path;

	GuitarProFile gpx = new GuitarProFile(file);
//	gpx.WriteText(file.filepath.stripExtension ~ ".txt");

	song.LoadGPx(gpx);

	// search for music files
	//...

	return song;
}

bool LoadGPx(Song song, GuitarProFile gpx)
{
	with(song) with(GuitarProFile)
	{
		// parse timing

		// creating starting BPM event
//		gpx.tempo;

		foreach(ref m; gpx.measures)
		{
			if(m.has(MeasureInfo.Bits.TSNumerator) || m.has(MeasureInfo.Bits.TSDenimonator))
			{
				// time signature event...
			}
		}

		foreach(ref t; gpx.tracks)
		{
			foreach(ref m; t.measures)
			{
				foreach(v; 0..2)
				{
					foreach(ref b; t.beats[m.voices[v].beat .. m.voices[v].beat+m.voices[v].numBeats])
					{
						if(b.mix && b.mix.tempo != -1)
						{
							// bpm event
						}
					}
				}
			}
		}

		// time sig in measure info
		// tempo in beat mix events

		// parse drums
		// midi track 10


		// how to identify the tracks...?

		// parse 'real' guitar and bass

		// parse keyboard

		// parse lyrics/vox
	}

	return false;
}
