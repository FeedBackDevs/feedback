module db.formats.gtp;

import fuji.fuji;
import fuji.filesystem;
import fuji.dbg;

import db.song;
import db.sequence;
import db.instrument;
import db.formats.parsers.midifile;
import db.formats.parsers.guitarprofile;
import db.tools.filetypes;
import db.songlibrary;

import std.string;
import std.path;

bool LoadGuitarPro(Track* track, DirEntry file)
{
	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

	track.contentPath = path;
	track.song = new Song;
//	track.song.songPath = path;
//	track.song.id = file.filename.stripExtension;

	// search for the music and other stuff...
	string songName = file.filename.stripExtension.toLower;
	foreach(f; dirEntries(path ~ "*", SpanMode.shallow))
	{
		string filename = f.filename.toLower;
		string fn = filename.stripExtension;
		if(isImageFile(filename))
		{
			if(fn[] == songName)
				track.cover = f.filename;
			else if(fn[] == songName ~ "-bg")
				track.background = f.filename;
		}
		else if(isAudioFile(filename))
		{
			if(fn[] == songName)
				track.addSource().addStream(f.filename);
			if(fn[] == "intro")
				track.preview = f.filename;
		}
		else if(isVideoFile(filename))
		{
			if(fn[] == songName)
				track.video = f.filename;
		}
	}

	GuitarProFile gpx = new GuitarProFile(file);
//	gpx.WriteText(file.filepath.stripExtension ~ ".txt");

	track.song.LoadGPx(gpx);

	// search for music files
	//...

	return true;
}

bool LoadGPx(Song song, GuitarProFile gpx)
{
	with(song) with(GuitarProFile)
	{
		// parse guitar pro file
		song.resolution = gpx.ticksPerBeat;

		song.startOffset = 410000;

		song.name = gpx.title;
		song.artist = gpx.artist;
		song.album = gpx.album;
		song.charterName = gpx.transcriber;
		
/+
		string songPath;

		string id;
		string subtitle;
		string year;
		string sourcePackageName;		// where did the song come from? (eg, "Rock Band II", "Guitar Hero Metallica", "Rush DLC", etc)

		string cover;					// cover image
		string background;				// background image
		string fretboard;				// custom fretboard graphic

		string tags;					// string tags for sorting/filtering
		string genre;
		string mediaType;				// media type for pfx theme purposes (cd/casette/vinyl/etc)

		string[string] params;			// optional key-value pairs (much data taken from the original .ini files, might be useful in future)

		string[MusicFiles.Count] musicFiles;
		string video;
+/

		// creating starting BPM event
		Event ev;
		ev.tick = 0;
		ev.event = EventType.BPM;
		ev.bpm.usPerBeat = cast(int)(60_000_000.0 / to!double(gpx.tempo) + 0.5);
		sync ~= ev;

		// parse sync
		int tn, td;
		foreach(i, ref m; gpx.measures)
		{
			if((m.has(MeasureInfo.Bits.TSNumerator) || m.has(MeasureInfo.Bits.TSDenimonator) || i == 0) && (m.tn != tn || m.td != td))
			{
				// time signature event...
				ev.tick = m.tick;
				ev.event = EventType.TimeSignature;
				ev.ts.numerator = m.tn;
				ev.ts.denominator = m.td;
				sync ~= ev;
			}

			foreach(ref t; gpx.tracks)
			{
				Measure *tm = &t.measures[i];

				foreach(v; 0..2)
				{
					Beat[] beats = t.beats[tm.voices[v].beat .. tm.voices[v].beat+tm.voices[v].numBeats];
					foreach(ref b; beats)
					{
						if(b.mix && b.mix.tempo != -1)
						{
							ev.tick = b.tick;
							ev.event = EventType.BPM;
							ev.bpm.usPerBeat = cast(int)(60_000_000.0 / to!double(b.mix.tempo) + 0.5);
							sync ~= ev;
						}
					}
				}
			}
		}

		foreach(ref t; gpx.tracks)
		{
			// how to identify the tracks...?

			if(t.channel == 10)
			{
				SongPart* part = &song.parts[Part.Drums];

				part.part = Part.Drums;
				part.variations ~= Variation(t.name ~ "-8drums");
				Variation *variation = &part.variations[$-1];

				Sequence seq = new Sequence();
				seq.part = part.part;
				seq.variation = variation.name;
				seq.difficulty = "Expert";
				variation.difficulties ~= seq;

				// parse drums
				ptrdiff_t[STRING_MAX_NUMBER][2] lastNotes = -1;
				foreach(mi, ref m; t.measures)
				{
					foreach(v; 0..2)
					{
						foreach(ref b; t.beats[m.voices[v].beat .. m.voices[v].beat+m.voices[v].numBeats])
						{
							if(b.has(Beat.Bits.Text))
							{
								ev.tick = b.tick;
								ev.event = EventType.Event;
								ev.text = b.text;
								part.events ~= ev;
							}

							foreach(s, n; b.notes)
							{
								if(n == null)
								{
/+
									if(lastNotes[v][s] >= 0)
									{
										if(seq.notes[lastNotes[v][s]].duration <= gpx.ticksPerBeat / 2)
											seq.notes[lastNotes[v][s]].duration = 0;
										lastNotes[v][s] = -1;
									}
+/
									continue;
								}
								switch(n.type)
								{
									case Note.Type.None:
										int x = 0;
										break;
									case Note.Type.Normal:
										assert(n.fret >= 35 && n.fret <= 81, "Invalid note!");

										struct DrumMap
										{
											int note;
											uint flags;
										}
										__gshared immutable DrumMap[82-35] drumMap = [
											{ DrumNotes.Kick, 0 }, //35 Bass Drum 2
											{ DrumNotes.Kick, 0 }, //36 Bass Drum 1
											{ DrumNotes.Snare, MFBit!(DrumNoteFlags.RimShot) }, //37 Side Stick/Rimshot
											{ DrumNotes.Snare, 0 }, //38 Snare Drum 1
											{ -1, 0 }, //39 Hand Clap
											{ DrumNotes.Snare, 0 }, //40 Snare Drum 2
											{ DrumNotes.Tom3, 0 }, //41 Low Tom 2
											{ DrumNotes.Hat, 0 }, //42 Closed Hi-hat
											{ DrumNotes.Tom3, 0 }, //43 Low Tom 1
											{ DrumNotes.Hat, 0 }, //44 Pedal Hi-hat
											{ DrumNotes.Tom2, 0 }, //45 Mid Tom 2
											{ DrumNotes.Hat, MFBit!(DrumNoteFlags.OpenHat) }, //46 Open Hi-hat
											{ DrumNotes.Tom2, 0 }, //47 Mid Tom 1
											{ DrumNotes.Tom1, 0 }, //48 High Tom 2
											{ DrumNotes.Crash, 0 }, //49 Crash Cymbal 1
											{ DrumNotes.Tom1, 0 }, //50 High Tom 1
											{ DrumNotes.Ride, 0 }, //51 Ride Cymbal 1
											{ DrumNotes.Splash, 0 }, //52 Chinese Cymbal
											{ DrumNotes.Ride, MFBit!(DrumNoteFlags.CymbalBell) }, //53 Ride Bell
											{ -1, 0 },//DrumNotes.Cowbell, 0 }, //54 Tambourine
											{ DrumNotes.Splash, 0 }, //55 Splash Cymbal
											{ -1, 0 },//DrumNotes.Cowbell, 0 }, //56 Cowbell
											{ DrumNotes.Splash, 0 }, //57 Crash Cymbal 2
											{ -1, 0 }, //58 Vibra Slap
											{ DrumNotes.Ride, 0 }, //59 Ride Cymbal 2
											{ -1, 0 }, //60 High Bongo
											{ -1, 0 }, //61 Low Bongo
											{ -1, 0 }, //62 Mute High Conga
											{ -1, 0 }, //63 Open High Conga
											{ -1, 0 }, //64 Low Conga
											{ -1, 0 }, //65 High Timbale
											{ -1, 0 }, //66 Low Timbale
											{ -1, 0 }, //67 High Agogô
											{ -1, 0 }, //68 Low Agogô
											{ -1, 0 }, //69 Cabasa
											{ -1, 0 }, //70 Maracas
											{ -1, 0 }, //71 Short Whistle
											{ -1, 0 }, //72 Long Whistle
											{ -1, 0 }, //73 Short Güiro
											{ -1, 0 }, //74 Long Güiro
											{ -1, 0 }, //75 Claves
											{ -1, 0 }, //76 High Wood Block
											{ -1, 0 }, //77 Low Wood Block
											{ -1, 0 }, //78 Mute Cuíca
											{ -1, 0 }, //79 Open Cuíca
											{ -1, 0 }, //80 Mute Triangle
											{ -1, 0 } //81 Open Triangle
										];

										int dn = n.fret - 35;
										if(drumMap[dn].note != -1)
										{
											ev.tick = n.tick;
											ev.event = EventType.Note;

											ev.duration = 0;//n.duration;

											ev.note.key = drumMap[dn].note;
											ev.flags = drumMap[dn].flags;

											seq.notes ~= ev;
											lastNotes[v][s] = seq.notes.length-1;
										}
										break;
									case Note.Type.Ghost:
//										if(lastNotes[v][s] >= 0)
//											seq.notes[lastNotes[v][s]].duration += n.duration;
										break;
									case Note.Type.Tie:
										int x = 0;
										break;
									default:
										int x = 0;
								}
							}
						}
					}
				}

				foreach(v; 0..2)
				{
					foreach(n; lastNotes[v])
					{
						if(n >= 0)
						{
							if(seq.notes[n].duration <= gpx.ticksPerBeat / 2)
								seq.notes[n].duration = 0;
						}
					}
				}
			}

			// parse 'real' guitar and bass

			// parse keyboard

			// parse lyrics/vox
		}
	}

	return false;
}
