module db.song;

import db.sequence;
import db.tools.midifile;

import fuji.material;
import fuji.sound;

import std.conv;

enum SyncEventType
{
	BPM,
	Anchor,
	TimeSignature
}

enum SongEventType
{
	Event,
}

struct SyncEvent
{
	SyncEventType event;

	long time;		// the real-time of the note (in microseconds)
	int tick;		// in ticks
	union
	{
		int bpm;		// in thousandths of a beat per minute
		int timeSignature;
	}
}

struct SongEvent
{
	SongEventType type;

	long time;		// the physical time of the note (in microseconds)
	int tick;		// in ticks

	string event;
}

class Song
{
	this(string filename = null)
	{
	}

	this(MIDIFile midi)
	{
		enum GHVersion { Unknown, GH, GH2, GH3, GHWT, GHA, GHM, GH5, GHWoR, BH, RB, RB2, RB3 }
		GHVersion ghVer;

		assert(midi.format == 1, "Unsupported midi format!");

		resolution = midi.ticksPerBeat;

		foreach(i, t; midi.tracks)
		{
			auto name = t.getFront();
			while(!name.isEvent(MIDIEvents.TrackName))
				name = t.getFront();

			assert(name.isEvent(MIDIEvents.TrackName), "Expected track name");

			Part part;

			// detect which track we're looking at
			if(i == 0)
			{
				id = name.text;
			}
			else
			{
				switch(name.text)
				{
					case "T1 GEMS":
						ghVer = GHVersion.GH;
						part = Part.LeadGuitar;
						break;
					case "PART GUITAR":	part = Part.LeadGuitar; break;
					case "PART DRUMS":	part = Part.Drums; break;
					case "PART RHYTHM":	part = Part.RhythmGuitar; break;
					case "PART BASS":	part = Part.Bass; break;
					case "PART GUITAR COOP":
						// TODO: present in GH2 songs, what should we do with this?
						// we should probably support 'variants' for parts...
						// this way it is also possible to support songs that appeared in different versions of GH/RB games.
						continue;
					case "PART VOCALS":	part = Part.Vox; break;
					case "EVENTS":
						break;
					case "VENUE":
						break;
					case "BAND SINGER":
						// Contains text events that control the animation state of the band singer.
						continue;
					case "BAND BASS":
						// Contains text events that control the animation state of the band bassist.
						// If the co-op track is rhythm guitar, this track will also contain fret hand animation note data for the bassist in the same format as the lead guitar track.
						continue;
					case "BAND DRUMS":
						// Contains text events that control the animation state of the band drummer.
						continue;
					case "BAND KEYS":
						// Contains text events that control the animation state of the band keyboard player.
						continue;
					case "TRIGGERS":
						// GH1 + GH2: The contents of this track are not known.
						continue;
					case "ANIM":
						// GH1: This track contains events used to control the animation of the hands of the guitarist.
						continue;
					case "BEAT":
						// This track counts the beats, 'on' on 1's, 'off's on other beats.
						continue;
					default:
						MFDebug_Warn(2, "Unknown track: " ~ name.text);
				}

				if(part != Part.Unknown)
				{
					foreach(d; Difficulty.Easy .. Difficulty.Count)
						tracks[sequenceIndex(part, d)] = new Sequence(part, d);
				}
			}

			// parse the events
			foreach(e; t)
			{
				if(e.type == MIDIEventType.Custom)
				{
					switch(e.subType) with(MIDIEvents)
					{
						// sync track events
						case TimeSignature:
							assert(e.timeSignature.denominator == 2 && e.timeSignature.clocks == 24 && e.timeSignature.d == 8, "Unexpected!");

							SyncEvent se;
							se.event = SyncEventType.TimeSignature;
							se.tick = e.tick;
							se.timeSignature = e.timeSignature.numerator;
							sync ~= se;
							break;
						case Tempo:
							SyncEvent se;
							se.event = SyncEventType.BPM;
							se.tick = e.tick;
							se.bpm = cast(int)(e.tempo.BPM * 1000.0); // TODO: this is lossy! fix this later...
							sync ~= se;
							break;

						// other track events
						case Text:
							string text = e.text;
							if(text[0] == '[' && text[$-1] == ']')
								text = text[1..$-1];

							// it's an event
							string event = e.text[1..$-1];
							if(part == Part.Unknown)
							{
								// stash it in the events track
								SongEvent ev;
								ev.type = SongEventType.Event;
								ev.tick = e.tick;
								ev.event = e.text;
								events ~= ev;
							}
							else
							{
								// stash it in the part (all difficulties)
								Event ev;
								ev.event = EventType.Event;
								ev.tick = e.tick;
								ev.stringParam = e.text;

								foreach(d; Difficulty.Easy .. Difficulty.Count)
									tracks[sequenceIndex(part, d)].notes ~= ev;
							}
							break;
						case Lyric:
							// TODO: lyrics for vox track...
							break;
						case EndOfTrack:
							// TODO: should we validate that the track actually ends?
							break;
						default:
							MFDebug_Warn(2, "Unexpected event: " ~ to!string(e.subType));
					}
				}
				else if(e.type == MIDIEventType.Note)
				{
					switch(part)
					{
						case Part.LeadGuitar:
						case Part.RhythmGuitar:
						case Part.Bass:
						case Part.Drums:
							Event ev;
							ev.tick = e.tick;

							// if it within a difficulty bracket?
							Difficulty difficulty = Difficulty.Count;
							if(e.note.note >= 60 && e.note.note < 72)
								difficulty = Difficulty.Easy;
							else if(e.note.note >= 72 && e.note.note < 84)
								difficulty = Difficulty.Medium;
							else if(e.note.note >= 84 && e.note.note < 96)
								difficulty = Difficulty.Hard;
							else if(e.note.note >= 96 && e.note.note < 108)
								difficulty = Difficulty.Expert;

							if(difficulty < Difficulty.Count)
							{
								int[Difficulty.Count] offset = [ 60, 72, 84, 96 ];
								int note = e.note.note - offset[difficulty];

								if(note <= 4)
								{
									ev.event = EventType.Note;
									ev.key = e.note.note - 60;
								}
								else if(note == 7)
									ev.event = EventType.StarPower;
								else if(note == 9)
									ev.event = EventType.LeftPlayer;
								else if(note == 10)
									ev.event = EventType.RightPlayer;

								tracks[sequenceIndex(part, difficulty)].notes ~= ev;
							}
							else
							{
								// events here are not difficulty specific, and apply to all difficulties
								switch(ev.key)
								{
//									case 108: ev.event = EventType.; break; // singer mouth open/close
//									case 110: ev.event = ???; break;		// unknown event added to GH2
									case 116: ev.event = EventType.Overdrive; break;
									case 124: ev.event = EventType.FreeStyle; break;
									default:
										// TODO: there are still a bunch of unknown notes...
//										MFDebug_Warn(2, "Unknown note: " ~ to!string(part) ~ " " ~ to!string(e.note.note));
										break;
								}

								if(ev.event != EventType.Unknown)
								{
									foreach(d; Difficulty.Easy .. Difficulty.Count)
										tracks[sequenceIndex(part, d)].notes ~= ev;
								}
							}
							break;

						case Part.Vox:
							break;

						default:
							// TODO: there are still many notes in unknown parts...
							break;
					}
				}
				else
					MFDebug_Warn(2, "Invalid event type: " ~ to!string(e.type));
			}
		}
	}


	~this()
	{
	}

	void SaveChart()
	{
	}

	void Play(long time)
	{
	}

	void Stop()
	{
	}

	void SetVolume(float volume)
	{
	}

	void SetPan(float pan)
	{
	}

	int GetLastNoteTick()
	{
		return 0;
	}

	int GetStartBPM()
	{
		return 0;
	}

	void CalculateNoteTimes(int stream, int startTick)
	{
	}

	long CalculateTimeOfTick(int tick)
	{
		return 0;
	}

	int CalculateTickAtTime(long time, int *pBPM = null)
	{
		return 0;
	}

	// data...
	string songPath;

	string id;
	string name;
	string artist;
	string album;
	string year;
	string sourcePackageName;	// where did the song come from? (eg, "Rock Band II", "Guitar Hero Metallica", "Rush DLC", etc)
	string charterName;

	string cover;			// cover image
	string background;		// background image
	string fretboard;		// custom fretboard graphic

	string tags;			// string tags for sorting/filtering
	string genre;
	string mediaType;		// media type for pfx theme purposes (cd/casette/vinyl/etc)

	string[string] params;	// optional key-value pairs (much data taken from the original .ini files, might be useful in future)

	// paths to music files (many of these may or may not be available for different songs)
	string previewFilename;
	string songFilename;			// the backing track (often includes vocals)
	string songWithCrowdFilename;	// backing track with crowd sing-along (sing-along, for star-power mode/etc.)
	string vocalsFilename;			// discreet vocal track
	string crowdFilename;			// crowd-sing-along, for star-power/etc.
	string guitarFilename;
	string rhythmFilename;
	string bassFilename;
	string keysFilename;
	string drumsFilename;			// drums mixed to a single track

	// paths to music for split drums (guitar hero world tour songs split the drums into separate tracks)
	string kickFilename;
	string snareFilename;
	string cymbalsFilename;	// all cymbals
	string tomsFilename;	// all toms

	// multitrack support? (Rock Band uses .mogg files; multitrack ogg files)
//	string multitrackFilename;		// multitrack filename (TODO: this will take some work...)
//	Instrument[] trackAssignment;	// assignment of each track to parts

	// song data
	long startOffset;		// starting offset, in microseconds

	int resolution;

	SyncEvent[] sync;		// song sync stuff
	SongEvent[] events;		// general song events (effects, lighting, etc?)
	Sequence[NumSequences] tracks;

	MFMaterial *pFretboard;

	MFAudioStream *pSong;
	MFAudioStream *pSongWithCrowd;
	MFAudioStream *pVocals;
	MFAudioStream *pCrowd;
	MFAudioStream *pGuitar;
	MFAudioStream *pRhythm;
	MFAudioStream *pBass;
	MFAudioStream *pKeys;
	MFAudioStream *pDrums;
	MFAudioStream *pKick;
	MFAudioStream *pSnare;
	MFAudioStream *pCymbals;
	MFAudioStream *pToms;
}
