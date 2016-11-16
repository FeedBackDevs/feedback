module db.formats.rawmidi;

import fuji.dbg;
import fuji.filesystem;
import fuji.fuji;

import db.chart;
import db.formats.parsers.midifile;
import db.instrument;
import db.instrument.drums : DrumNotes, DrumNoteFlags;
import db.library;
import db.tools.filetypes;

import std.algorithm : canFind;
import std.conv : to;
import std.path;
import std.range : back;
import std.string;

bool LoadRawMidi(Song* song, DirEntry file)
{
	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

	song._chart = new Chart;
	song._chart.params["source_format"] = ".midi";

	song._chart.name = file.filename.stripExtension;

	MIDIFile midi = new MIDIFile(file);
//	midi.WriteText(file.filepath.stripExtension ~ ".txt");

	song._chart.LoadRawMidi(midi);

	// search for the music and other stuff...
	string songName = file.filename.stripExtension.toLower;
	foreach (f; dirEntries(path ~ "*", SpanMode.shallow))
	{
		string filename = f.filename.toLower;
		string fn = filename.stripExtension;
		if (isImageFile(filename))
		{
			if (fn[] == songName)
				song.coverImage = f.filepath;
			else if (fn[] == songName || fn[] == songName ~ "-bg")
				song.background = f.filepath;
		}
		else if (isAudioFile(filename))
		{
			if (fn[] == songName)
				song.addSource().addStream(f.filepath);
			if (fn[] == songName ~ "-intro")
				song._preview = f.filepath;
		}
		else if (isVideoFile(filename))
		{
			if (fn[] == songName)
				song.video = f.filepath;
		}
	}

	return true;
}

bool LoadRawMidi(Chart song, MIDIFile midi)
{
	with(song)
	{
		if (midi.format != 1)
		{
			MFDebug_Warn(2, "Unsupported midi format!".ptr);
			return false;
		}

		resolution = midi.ticksPerBeat;

		auto tracks = midi.tracks;

		foreach (track, events; tracks)
		{
			string part = "unknown";
			bool bIsEventTrack = true;
			Part* pPart;
			Variation* pVariation;

			// detect which track we're looking at
			if (track == 0)
			{
				// is sync track
			}
			else
			{
				// search for channel 9; drums
				bool bDrums = canFind!((a) => a.type == MIDIEventType.NoteOn && a.note.channel == 9)(events);

				// search for lyrics; vox
				bool bVox = !bDrums && canFind!((a) => a.isEvent(MIDIEvents.Lyric))(events);

				if (bDrums)
				{
					part = "drums";
					pPart = getPart(part, true);
					pVariation = pPart.variation("8-drums", "Track " ~ to!string(track + 1), true);

					Track trk = new Track();
					trk.part = part;
					trk.variationType = pVariation.type;
					trk.variationName = pVariation.name;
					trk.difficulty = Difficulty.Expert;
					pVariation.addDifficulty(trk);
				}
				else if (bVox)
				{
					part = "vocals";
				}
			}

			// parse the events
			MIDIEvent*[128][16] currentNotes;
			Event*[128][16] currentEvents;
			foreach (ref e; events)
			{
				Event ev;
				ev.tick = e.tick;

				int note = e.note.note;
				int channel = e.note.channel;

				if (e.type == MIDIEventType.Custom)
				{
					switch (e.subType) with(MIDIEvents)
					{
						// sync track events
						case TimeSignature:
							ev.event = EventType.TimeSignature;
							ev.ts.numerator = e.timeSignature.numerator;
							ev.ts.denominator = 1 << e.timeSignature.denominator;
//							x = e.timeSignature.clocks;
//							y = e.timeSignature.d;
							sync ~= ev;
							break;
						case Tempo:
							ev.event = EventType.BPM;
							ev.bpm.usPerBeat = e.tempo.microsecondsPerBeat;
							sync ~= ev;
							break;

							// other track events
						case Text:
							string text = e.text.strip;

							if (part[] == "unknown")
							{
								// stash it in the events track
								ev.event = EventType.Event;
								ev.text = text;
								song.events ~= ev;
							}
							else
							{
								// stash it in the part (all difficulties)
								ev.event = EventType.Event;
								ev.text = text;
								pPart.events ~= ev;
							}
							break;
						case Lyric:
							if (part[] != "vocals")
							{
								MFDebug_Warn(2, "Lyrics not on Vox track?!".ptr);
								continue;
							}

							ev.event = EventType.Lyric;
							ev.text = e.text;

							// Note: keeping lyrics in variation means we can support things like 'misheard lyric' variations ;)
							pVariation.difficulties[0].notes ~= ev;
							break;
						case EndOfTrack:
							break;
						default:
							MFDebug_Warn(2, "Unexpected event: " ~ to!string(e.subType));
					}
					continue;
				}

				if (e.type != MIDIEventType.NoteOff && e.type != MIDIEventType.NoteOn)
				{
					MFDebug_Warn(2, "Unexpected event: " ~ to!string(e.type));
					continue;
				}
				if (e.type == MIDIEventType.NoteOff || (e.type == MIDIEventType.NoteOn && e.note.velocity == 0))
				{
					if (currentNotes[channel][note] == null)
					{
						MFDebug_Warn(2, "Note already up: " ~ to!string(note));
						continue;
					}

					// calculate and set note duration that this off event terminates
					int duration = e.tick - currentNotes[channel][note].tick;

					// Note: 240 (1/8th) seems like an established minimum sustain
					if (part[] != "drums" && duration >= 240 && currentEvents[channel][note])
						currentEvents[channel][note].duration = duration;

					currentNotes[channel][note] = null;
					currentEvents[channel][note] = null;
					continue;
				}
				if (e.type == MIDIEventType.NoteOn)
				{
					if (currentNotes[channel][note] != null)
						MFDebug_Warn(2, "Note already down: " ~ to!string(note));

					currentNotes[channel][note] = &e;
				}

				switch (part)
				{
					case "drums":
						assert(note >= 35 && note <= 81, "Invalid note!");

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

						int n = note - 35;
						if (drumMap[n].note != -1)
						{
							ev.event = EventType.Note;
							ev.note.key = drumMap[n].note;
							ev.flags = drumMap[n].flags;

							pVariation.difficulties[0].notes ~= ev;
							currentEvents[channel][note] = &pVariation.difficulties[0].notes.back;
						}

						break;
					case "vocals":
						// TODO: read vox...
						break;
					default:
						// TODO: there are still many notes in unknown parts...
						break;
				}
			}
		}

		return false;
	}
}
