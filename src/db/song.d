module db.song;

import db.sequence;
import db.tools.midifile;

import fuji.material;
import fuji.sound;

import std.conv : to;
import std.string : toStringz;

// music files (many of these may or may not be available for different songs)
enum MusicFiles
{
	Preview,		// the backing track (often includes vocals)
	Song,			// backing track with crowd sing-along (sing-along, for star-power mode/etc.)
	SongWithCrowd,	// discreet vocal track
	Vocals,			// crowd-sing-along, for star-power/etc.
	Crowd,
	Guitar,
	Rhythm,
	Bass,
	Keys,
	Drums,			// drums mixed to a single track

	// paths to music for split drums (guitar hero world tour songs split the drums into separate tracks)
	Kick,
	Snare,
	Cymbals,		// all cymbals
	Toms,			// all toms

	Count
}

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

struct Variation
{
	string name;
	Sequence[] difficulties;
}

class Song
{
	this(string filename = null)
	{
	}

	this(MIDIFile midi)
	{
		immutable auto difficulties = [ "Easy", "Medium", "Hard", "Expert" ];

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
			string variation = "Default";
			ptrdiff_t v = -1;

			// detect which track we're looking at
			if(i == 0)
			{
				MFDebug_Log(3, "Track: SYNC".ptr);
				id = name.text;
			}
			else
			{
				MFDebug_Log(3, "Track: " ~ name.text);

				switch(name.text)
				{
					case "T1 GEMS":
						ghVer = GHVersion.GH;
						part = Part.LeadGuitar;
						break;
					case "PART GUITAR":			part = Part.LeadGuitar; break;
					case "PART GUITAR COOP":	part = Part.LeadGuitar; variation = "Co-op"; break;
					case "PART RHYTHM":			part = Part.RhythmGuitar; break;
					case "PART BASS":			part = Part.Bass; break;
					case "PART DRUMS":			part = Part.Drums; break;
					case "PART VOCALS":			part = Part.Vox; break;
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
					v = variations[part].length;
					variations[part] ~= Variation(variation);

					// Note: Vox track only has one difficulty...
					variations[part][v].difficulties = new Sequence[part == Part.Vox ? 1 : difficulties.length];
					foreach(j, ref d; variations[part][v].difficulties)
					{
						d = new Sequence;
						d.part = part;
						d.variation = variation;
						d.difficulty = part == Part.Vox ? "Default" : difficulties[j];
						d.difficultyMeter = 0; // TODO: I think we can pull this from songs.ini?
					}
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
							{
								// it's an event
								text = text[1..$-1];

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

									foreach(seq; variations[part][v].difficulties)
										seq.notes ~= ev;
								}
							}
							else if(part == Part.Vox)
							{
								// Note: some songs seem to use strings without [] instead of lyrics
								goto case Lyric;
							}
							break;
						case Lyric:
							if(part != Part.Vox)
							{
								MFDebug_Warn(2, "Lyrics not on Vox track?!".ptr);
								continue;
							}

							Event ev;
							ev.event = EventType.Lyric;
							ev.tick = e.tick;
							ev.stringParam = e.text;

							variations[part][v].difficulties[0].notes ~= ev;
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
							int difficulty = -1;
							if(e.note.note >= 60 && e.note.note < 72)
								difficulty = 0;
							else if(e.note.note >= 72 && e.note.note < 84)
								difficulty = 1;
							else if(e.note.note >= 84 && e.note.note < 96)
								difficulty = 2;
							else if(e.note.note >= 96 && e.note.note < 108)
								difficulty = 3;

							if(difficulty != -1)
							{
								int[4] offset = [ 60, 72, 84, 96 ];
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

								variations[part][v].difficulties[difficulty].notes ~= ev;
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
									foreach(seq; variations[part][v].difficulties)
										seq.notes ~= ev;
								}
							}
							break;

						case Part.Vox:
							// TODO: read vox...
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
		// release the resources
		Release();
	}

	void SaveChart()
	{
		// TODO: develop a format for the note chart files...
	}

	void Prepare()
	{
		if(cover)
			pCover = MFMaterial_Create((songPath ~ cover).toStringz);
		if(background)
			pBackground = MFMaterial_Create((songPath ~ background).toStringz);
		if(fretboard)
			pFretboard = MFMaterial_Create((songPath ~ fretboard).toStringz);

		foreach(i, m; musicFiles)
		{
			if(m && i != MusicFiles.Preview)
			{
				pMusic[i] = MFSound_CreateStream((songPath ~ m).toStringz, MFAudioStreamFlags.QueryLength | MFAudioStreamFlags.AllowSeeking);
				MFSound_PlayStream(pMusic[i], MFPlayFlags.BeginPaused);
				pVoices[i] = MFSound_GetStreamVoice(pMusic[i]);
//				MFSound_SetPlaybackRate(pVoices[i], 1.0f); // TODO: we can use this to speed/slow the song...
			}
		}
	}

	void Release()
	{
		foreach(ref s; pMusic)
		{
			if(s)
			{
				MFSound_DestroyStream(s);
				s = null;
			}
		}

		if(pCover)
		{
			MFMaterial_Release(pCover);
			pCover = null;
		}
		if(pBackground)
		{
			MFMaterial_Release(pBackground);
			pBackground = null;
		}
		if(pFretboard)
		{
			MFMaterial_Release(pFretboard);
			pFretboard = null;
		}
	}

	void Pause(bool bPause)
	{
		foreach(s; pMusic)
			if(s)
				MFSound_PauseStream(s, bPause);
	}

	void Seek(float offsetInSeconds)
	{
		foreach(s; pMusic)
			if(s)
				MFSound_SeekStream(s, offsetInSeconds);
	}

	void SetVolume(Part part, float volume)
	{
		// TODO: figure how parts map to playing streams
	}

	void SetPan(Part part, float pan)
	{
		// TODO: figure how parts map to playing streams
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
	string sourcePackageName;		// where did the song come from? (eg, "Rock Band II", "Guitar Hero Metallica", "Rush DLC", etc)
	string charterName;

	string cover;					// cover image
	string background;				// background image
	string fretboard;				// custom fretboard graphic

	string tags;					// string tags for sorting/filtering
	string genre;
	string mediaType;				// media type for pfx theme purposes (cd/casette/vinyl/etc)

	string[string] params;			// optional key-value pairs (much data taken from the original .ini files, might be useful in future)

	string[MusicFiles.Count] musicFiles;

	// multitrack support? (Rock Band uses .mogg files; multitrack ogg files)
//	string multitrackFilename;		// multitrack filename (TODO: this will take some work...)
//	Instrument[] trackAssignment;	// assignment of each track to parts

	// song data
	int resolution;

	long startOffset;				// starting offset, in microseconds

	SyncEvent[] sync;				// song sync stuff
	SongEvent[] events;				// general song events (effects, lighting, etc?)
	Variation[][Part.Count] variations;

	MFMaterial *pCover;
	MFMaterial *pBackground;
	MFMaterial *pFretboard;

	MFAudioStream*[MusicFiles.Count] pMusic;
	MFVoice*[MusicFiles.Count] pVoices;
}
