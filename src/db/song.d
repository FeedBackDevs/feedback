module db.song;

import db.sequence;
import db.tools.midifile;

import fuji.material;
import fuji.sound;

import std.conv : to;
import std.range : empty, back;
import std.algorithm : max;
import std.string;


enum GHVersion { Unknown, GH, GH2, GH3, GHWT, GHA, GHM, GH5, GHWoR, BH, RB, RB2, RB3 }

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

struct SongPart
{
	Part part;
	Event[] events;			// events for the entire part (animation, etc)
	Variation[] variations;	// variations for the part (different versions, instrument variations (4/5/pro drums, etc), customs...
}

struct Variation
{
	string name;
	Sequence[] difficulties;	// sequences for each difficulty
}

class Song
{
	this(string filename = null)
	{
	}

	GHVersion DetectVersion(MIDIFile midi)
	{
		foreach(i, t; midi.tracks)
		{
			auto name = t.getFront();
			while(!name.isEvent(MIDIEvents.TrackName))
				name = t.getFront();

			if(name.text[] == "T1 GEMS")
				return GHVersion.GH;
		}

		return GHVersion.Unknown;
	}

	this(MIDIFile midi, GHVersion ghVer = GHVersion.Unknown)
	{
		immutable auto difficulties = [ "Easy", "Medium", "Hard", "Expert" ];

		assert(midi.format == 1, "Unsupported midi format!");

		if(ghVer == GHVersion.Unknown)
			ghVer = DetectVersion(midi);

		resolution = midi.ticksPerBeat;

		foreach(i, t; midi.tracks)
		{
			auto name = t.getFront();
			while(!name.isEvent(MIDIEvents.TrackName))
				name = t.getFront();

			assert(name.isEvent(MIDIEvents.TrackName), "Expected track name");

			Part part;
			bool bIsEventTrack = true;
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
					case "PART GUITAR":			part = Part.LeadGuitar; bIsEventTrack = false; break;
					case "PART GUITAR COOP":	part = Part.LeadGuitar; variation = "Co-op"; bIsEventTrack = false; break;
					case "PART RHYTHM":			part = Part.RhythmGuitar; bIsEventTrack = false; break;
					case "PART BASS":			part = Part.Bass; bIsEventTrack = false; break;
					case "PART DRUMS":			part = Part.Drums; bIsEventTrack = false; break;
					case "PART VOCALS":			part = Part.Vox; bIsEventTrack = false; break;
					case "EVENTS":
						break;
					case "VENUE":
						break;
					case "BAND SINGER":
						// Contains text events that control the animation state of the band singer.
						part = Part.Vox;
						break;
					case "BAND BASS":
						// Contains text events that control the animation state of the band bassist.
						// If the co-op track is rhythm guitar, this track will also contain fret hand animation note data for the bassist in the same format as the lead guitar track.
						part = Part.Bass;
						break;
					case "BAND DRUMS":
						// Contains text events that control the animation state of the band drummer.
						part = Part.Drums;
						break;
					case "BAND KEYS":
						// Contains text events that control the animation state of the band keyboard player.
						part = Part.Keys;
						break;
					case "TRIGGERS":
						// GH1 + GH2: The contents of this track are not known.
						break;
					case "ANIM":
						// GH1: This track contains events used to control the animation of the hands of the guitarist.
						part = Part.LeadGuitar;
						break;
					case "BEAT":
						// This track counts the beats, 'on' on 1's, 'off's on other beats.
						break;
					default:
						MFDebug_Warn(2, "Unknown track: " ~ name.text);
				}

				if(part != Part.Unknown && !bIsEventTrack)
				{
					v = parts[part].variations.length;
					parts[part].variations ~= Variation(variation);

					// Note: Vox track only has one difficulty...
					parts[part].variations[v].difficulties = new Sequence[part == Part.Vox ? 1 : difficulties.length];
					foreach(j, ref d; parts[part].variations[v].difficulties)
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
			MIDIEvent*[128] currentNotes;
			Event*[128] currentEvents;
			foreach(ref e; t)
			{
				Event ev;
				ev.tick = e.tick;

				if(e.type == MIDIEventType.Custom)
				{
					switch(e.subType) with(MIDIEvents)
					{
						// sync track events
						case TimeSignature:
							assert(e.timeSignature.denominator == 2 && e.timeSignature.clocks == 24 && e.timeSignature.d == 8, "Unexpected!");

							ev.event = EventType.TimeSignature;
							ev.ts.numerator = e.timeSignature.numerator;
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
							if(text[0] == '[' && text[$-1] == ']')
							{
								// it's an event
								text = text[1..$-1];
							}
							else if(part == Part.Vox && !bIsEventTrack)
							{
								// Note: some songs seem to use strings without [] instead of lyrics
								goto case Lyric;
							}

							if(part == Part.Unknown)
							{
								// stash it in the events track
								ev.event = EventType.Event;
								ev.text = text;
								events ~= ev;
							}
							else
							{
								// stash it in the part (all difficulties)
								ev.event = EventType.Event;
								ev.text = text;
								parts[part].events ~= ev;
							}
							break;
						case Lyric:
							if(part != Part.Vox)
							{
								MFDebug_Warn(2, "[" ~ name.text ~ "] Lyrics not on Vox track?!");
								continue;
							}

							ev.event = EventType.Lyric;
							ev.text = e.text;

							// Note: keeping lyrics in variation means we can support things like 'misheard lyric' variations ;)
							parts[part].variations[v].difficulties[0].notes ~= ev;
							break;
						case EndOfTrack:
							// TODO: should we validate that the track actually ends?
							break;
						default:
							MFDebug_Warn(2, "[" ~ name.text ~ "] Unexpected event: " ~ to!string(e.subType));
					}
					continue;
				}

				if(e.type != MIDIEventType.NoteOff && e.type != MIDIEventType.NoteOn)
				{
					MFDebug_Warn(2, "[" ~ name.text ~ "] Unexpected event: " ~ to!string(e.type));
					continue;
				}
				if(e.type == MIDIEventType.NoteOff || (e.type == MIDIEventType.NoteOn && e.note.velocity == 0))
				{
					if(currentNotes[e.note.note] == null)
					{
						MFDebug_Warn(2, "[" ~ name.text ~ "] Note already up: " ~ to!string(e.note.note));
						continue;
					}

					int duration = e.tick - currentNotes[e.note.note].tick;

					// Note: allegedly, in GH1, notes less than 161 length were rejected...
//					if(ghVer == GHVersion.GH && duration < 161 && !bIsEventTrack && currentEvents[e.note.note])
//					{
//						MFDebug_Warn(2, "[" ~ name.text ~ "] Note is invalid, must be removed: " ~ to!string(e.note.note));
//					}

					// Note: 240 (1/8th) seems like an established minimum sustain
					if(duration >= 240 && currentEvents[e.note.note])
						currentEvents[e.note.note].duration = duration;

					currentNotes[e.note.note] = null;
					currentEvents[e.note.note] = null;
					continue;
				}
				if(e.type == MIDIEventType.NoteOn)
				{
					if(currentNotes[e.note.note] != null)
						MFDebug_Warn(2, "[" ~ name.text ~ "] Note already down: " ~ to!string(e.note.note));

					currentNotes[e.note.note] = &e;
				}
				if(bIsEventTrack)
				{
/*
					// TODO: event track notes mean totally different stuff (scene/player animation, etc)
					ev.event = EventType.MIDI;
					ev.midi.type = e.type;
					ev.midi.subType = e.subType;
					ev.midi.channel = e.note.channel;
					ev.midi.note = e.note.note;
					ev.midi.velocity = e.note.velocity;
					if(part != Part.Unknown)
					{
						parts[part].events ~= ev;
						currentEvents[e.note.note] = &parts[part].events.back;
					}
					else
					{
						events ~= ev;
						currentEvents[e.note.note] = &events.back;
					}
*/
					continue;
				}

				switch(part)
				{
					case Part.LeadGuitar:
					case Part.RhythmGuitar:
					case Part.Bass:
					case Part.Drums:
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
								ev.note.key = note;
							}
							else if(note == 5)
							{
								// forced strum
							}
							else if(note == 6)
							{
								// forced pick
							}
							else if(note == 7)
							{
								ev.event = EventType.Special;
								ev.special = SpecialType.StarPower;
							}
							else if(note == 9)
							{
								ev.event = EventType.Special;
								ev.special = SpecialType.LeftPlayer;
							}
							else if(note == 10)
							{
								ev.event = EventType.Special;
								ev.special = SpecialType.RightPlayer;
							}
							else
								MFDebug_Warn(2, "[" ~ name.text ~ "] Unknown " ~ to!string(part) ~ " note: " ~ to!string(note));

							if(ev.event != EventType.Unknown)
							{
								parts[part].variations[v].difficulties[difficulty].notes ~= ev;
								currentEvents[e.note.note] = &parts[part].variations[v].difficulties[difficulty].notes.back;
							}
						}
						else
						{
							// events here are not difficulty specific, and apply to all difficulties
							switch(e.note.note)
							{
//								case 12-15:								// RB: h2h camera cuts and focus notes
//								case 40-59:								// RB - guitar/bass: fret animation
//								case 24-27, 30-31, 34-42, 46-51:		// RB - drums: animation 

								case 108:
									// GH1: singer mouth open/close
									if(ghVer == GHVersion.GH)
									{
										// TODO: this needs to be an event with duration...
										ev.event = EventType.Event;
										ev.text = "open_mouth";
										parts[Part.Vox].events ~= ev;
										currentEvents[e.note.note] = &parts[Part.Vox].events.back;
										continue;
									}
									goto default;

//								case 110: ev.event = ???; break;		// GH2: unknown guitar event

								case 110: .. case 112:
									// RB: tom's instead of cymbals
									if(part == Part.Drums)
									{
										// TODO: change the RBG cymbals to tom's

										// HACK: add them as separate notes so we can visualise them...
										ev.event = EventType.Note;
										ev.note.key = 5 + e.note.note-110;
										foreach(seq; parts[Part.Drums].variations[v].difficulties)
										{
											seq.notes ~= ev;
											currentEvents[e.note.note] = &seq.notes.back;	// TODO: *FIXME* this get's overwritten 4 times, and only the last one will get sustain!
										}
										continue;
									}
									goto default;

								case 116:
									ev.event = EventType.Special;
									ev.special = SpecialType.Overdrive;
									foreach(seq; parts[part].variations[v].difficulties)
									{
										seq.notes ~= ev;
										currentEvents[e.note.note] = &seq.notes.back;	// TODO: *FIXME* this get's overwritten 4 times, and only the last one will get sustain!
									}
									break;

								case 120:	// RB: drum fills
								case 121:
								case 122:
								case 123:
									// Note: Freestyle always triggers all notes from 120-124, so we'll ignore 120-123.
									break;
								case 124:
									ev.event = EventType.Special;
									ev.special = SpecialType.FreeStyle;
									foreach(seq; parts[part].variations[v].difficulties)
									{
										seq.notes ~= ev;
										currentEvents[e.note.note] = &seq.notes.back;	// TODO: *FIXME* this get's overwritten 4 times, and only the last one will get sustain!
									}
									break;

								default:
									// TODO: there are still a bunch of unknown notes...
//									MFDebug_Warn(2, "Unknown note: " ~ to!string(part) ~ " " ~ to!string(e.note.note));
									ev.event = EventType.MIDI;
									ev.midi.type = e.type;
									ev.midi.subType = e.subType;
									ev.midi.channel = e.note.channel;
									ev.midi.note = e.note.note;
									ev.midi.velocity = e.note.velocity;

									parts[part].events ~= ev;
									currentEvents[e.note.note] = &parts[part].events.back;
									continue;
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
		// load song data
		if(cover)
			pCover = MFMaterial_Create((songPath ~ cover).toStringz);
		if(background)
			pBackground = MFMaterial_Create((songPath ~ background).toStringz);
		if(fretboard)
			pFretboard = MFMaterial_Create((songPath ~ fretboard).toStringz);

		// prepare the music streams
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

		// calculate the note times for all tracks
		CalculateNoteTimes(events, 0);
		foreach(ref p; parts)
		{
			foreach(ref v; p.variations)
			{
				foreach(d; v.difficulties)
					CalculateNoteTimes(d.notes, 0);
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

	bool IsPartPresent(Part part)
	{
		return parts[part].variations != null;
	}

	int GetLastNoteTick()
	{
		// find the last event in the song
		int lastTick = sync.empty ? 0 : sync.back.tick;
		foreach(ref p; parts)
		{
			foreach(ref v; p.variations)
			{
				foreach(d; v.difficulties)
					lastTick = max(lastTick, d.notes.empty ? 0 : d.notes.back.tick);
			}
		}
		return lastTick;
	}

	int GetStartUsPB()
	{
		foreach(e; sync)
		{
			if(e.tick != 0)
				break;
			if(e.event == EventType.BPM || e.event == EventType.Anchor)
				return e.bpm.usPerBeat;
		}

		return 60000000/120; // microseconds per beat
	}

	void CalculateNoteTimes(E)(E[] stream, int startTick)
	{
		int offset = 0;
		uint microsecondsPerBeat = GetStartUsPB();
		long playTime = startOffset;
		long tempoTime = 0;

		foreach(si, ref sev; sync)
		{
			if(sev.event == EventType.BPM || sev.event == EventType.Anchor)
			{
				tempoTime = cast(long)(sev.tick - offset)*microsecondsPerBeat/resolution;

				// calculate event time (if event is not an anchor)
				if(sev.event != EventType.Anchor)
					sev.time = playTime + tempoTime;

				// calculate note times
				ptrdiff_t note = stream.GetNextEvent(offset);
				if(note != -1)
				{
					for(; note < stream.length && stream[note].tick < sev.tick; ++note)
						stream[note].time = playTime + cast(long)(stream[note].tick - offset)*microsecondsPerBeat/resolution;
				}

				// increment play time to BPM location
				if(sev.event == EventType.Anchor)
					playTime = sev.time;
				else
					playTime += tempoTime;

				// find if next event is an anchor or not
				for(auto i = si + 1; i < sync.length && sync[i].event != EventType.BPM; ++i)
				{
					if(sync[i].event == EventType.Anchor)
					{
						// if it is, we need to calculate the BPM for this interval
						long timeDifference = sync[i].time - sev.time;
						int tickDifference = sync[i].tick - sev.tick;
						sev.bpm.usPerBeat = cast(uint)(timeDifference*resolution/tickDifference);
						break;
					}
				}

				// update microsecondsPerBeat
				microsecondsPerBeat = sev.bpm.usPerBeat;

				offset = sev.tick;
			}
			else
			{
				sev.time = playTime + cast(long)(sev.tick - offset)*microsecondsPerBeat/resolution;
			}
		}

		// calculate remaining note times
		ptrdiff_t note = stream.GetNextEvent(offset);
		if(note != -1)
		{
			for(; note < stream.length; ++note)
				stream[note].time = playTime + cast(long)(stream[note].tick - offset)*microsecondsPerBeat/resolution;
		}
	}

	long CalculateTimeOfTick(int tick)
	{
		int offset, currentUsPB;
		long time;

		Event *pEv = GetMostRecentSyncEvent(tick);
		if(pEv)
		{
			time = pEv.time;
			offset = pEv.tick;
			currentUsPB = pEv.bpm.usPerBeat;
		}
		else
		{
			time = startOffset;
			offset = 0;
			currentUsPB = GetStartUsPB();
		}

		if(offset < tick)
			time += cast(long)(tick - offset)*currentUsPB/resolution;

		return time;
	}

	Event* GetMostRecentSyncEvent(int tick)
	{
		auto e = sync.GetMostRecentEvent(tick, EventType.BPM, EventType.Anchor);
		return e < 0 ? null : &sync[e];
	}

	Event* GetMostRecentSyncEventTime(long time)
	{
		auto e = sync.GetMostRecentEventByTime(time, EventType.BPM, EventType.Anchor);
		return e < 0 ? null : &sync[e];
	}

	int CalculateTickAtTime(long time, int *pUsPerBeat = null)
	{
		uint currentUsPerBeat;
		long lastEventTime;
		int lastEventOffset;

		Event *e = GetMostRecentSyncEventTime(time);

		if(e)
		{
			lastEventTime = e.time;
			lastEventOffset = e.tick;
			currentUsPerBeat = e.bpm.usPerBeat;
		}
		else
		{
			lastEventTime = startOffset;
			lastEventOffset = 0;
			currentUsPerBeat = GetStartUsPB();
		}

		if(pUsPerBeat)
			*pUsPerBeat = currentUsPerBeat;

		return lastEventOffset + cast(int)((time - lastEventTime)*resolution/currentUsPerBeat);
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

	Event[] sync;					// song sync stuff
	Event[] events;					// general song/venue events (sections, effects, lighting, etc?)
	SongPart[Part.Count] parts;

	MFMaterial* pCover;
	MFMaterial* pBackground;
	MFMaterial* pFretboard;

	MFAudioStream*[MusicFiles.Count] pMusic;
	MFVoice*[MusicFiles.Count] pVoices;
}


// Binary search on the events
// before: true = return event one before requested time, false = return event one after requested time
// type: "tick", "time" to search by tick or by time
private ptrdiff_t GetEventForOffset(bool before, bool byTime)(Event[] events, long offset)
{
	enum member = byTime ? "time" : "tick";

	if(events.empty)
		return -1;

	// get the top bit
	size_t i = events.length, topBit = 0;
	while((i >>= 1))
		++topBit;
	i = topBit = 1 << topBit;

	// binary search bitchez!!
	ptrdiff_t target = -1;
	while(topBit)
	{
		if(i >= events.length) // if it's an invalid index
		{
			i = (i & ~topBit) | topBit>>1;
		}
		else if(mixin("events[i]." ~ member) == offset)
		{
			// return the first in sequence
			while(i > 0 && mixin("events[i-1]." ~ member) == mixin("events[i]." ~ member))
				--i;
			return i;
		}
		else if(mixin("events[i]." ~ member) > offset)
		{
			static if(!before)
				target = i;
			i = (i & ~topBit) | topBit>>1;
		}
		else
		{
			static if(before)
				target = i;
			i |= topBit>>1;
		}
		topBit >>= 1;
	}

	return target;
}

private template AllIs(Ty, T...)
{
	static if(T.length == 0)
		enum AllIs = true;
	else
		enum AllIs = is(T[0] == Ty) && AllIs!(T[1..$], Ty);
}

// skip over events of specified types
ptrdiff_t SkipEvents(bool reverse = false, E, Types...)(E[] events, ptrdiff_t e, Types types) if(AllIs!(E.EventType, Types))
{
	outer: for(; (reverse && e >= 0) || (!reverse && e < events.length); e += reverse ? -1 : 1)
	{
		foreach(t; types)
		{
			if(events[e].event == t)
				continue outer;
		}
		return e;
	}
	return -1;
}

// skip events until we find one we're looking for
ptrdiff_t SkipToEvents(bool reverse = false, Types...)(Event[] events, ptrdiff_t e, Types types) if(AllIs!(EventType, Types))
{
	for(; (reverse && e >= 0) || (!reverse && e < events.length); e += reverse ? -1 : 1)
	{
		foreach(t; types)
		{
			if(events[e].event == t)
				return e;
		}
	}
	return -1;
}

// get all events at specified tick
Event[] EventsAt(Event[] events, int tick)
{
	ptrdiff_t i = events.GetEventForOffset!(false, false)(tick);
	if(i != tick)
		return null;
	auto e = i;
	while(e < events.length-1 && events[e+1].tick == events[e].tick)
		++e;
	return events[i..e+1];
}

ptrdiff_t FindEvent(Event[] events, EventType type, int tick, int key = -1)
{
	// find the events at the requested offset
	auto ev = events.EventsAt(tick);
	if(!ev)
		return -1;

	// match the other conditions
	foreach(ref e; ev)
	{
		if(!type || e.event == type)
		{
			if(key == -1 || e.note.key == key)
				return &e - events.ptr; // return it as an index (TODO: should this return a ref instead?)
		}
	}
	return -1;
}

private ptrdiff_t GetEvent(bool reverse, bool byTime, Types...)(Event[] events, long offset, Types types) if(AllIs!(EventType, Types))
{
	ptrdiff_t e = events.GetEventForOffset!(reverse, byTime)(offset);
	if(e < 0 || Types.length == 0)
		return e;
	return events.SkipToEvents!reverse(e, types);
}

ptrdiff_t GetNextEvent(Types...)(Event[] events, int tick, Types types) if(AllIs!(EventType, Types))
{
	return events.GetEvent!(false, false)(tick, types);
}

ptrdiff_t GetNextEventByTime(Types...)(Event[] events, long time, Types types) if(AllIs!(EventType, Types))
{
	return events.GetEvent!(false, true)(time, types);
}

ptrdiff_t GetMostRecentEvent(Types...)(Event[] events, int tick, Types types) if(AllIs!(EventType, Types))
{
	return events.GetEvent!(true, false)(tick, types);
}

ptrdiff_t GetMostRecentEventByTime(Types...)(Event[] events, long time, Types types) if(AllIs!(EventType, Types))
{
	return events.GetEvent!(true, true)(time, types);
}

Event[] Between(Event[] events, int startTick, int endTick)
{
	assert(endTick >= startTick, "endTick must be greater than startTick");
	size_t first = events.GetNextEvent(startTick);
	size_t last = events.GetNextEvent(endTick+1);
	if(first == -1)
		return events[$..$];
	else if(last == -1)
		return events[first..$];
	else
		return events[first..last];
}

Event[] BetweenTimes(Event[] events, long startTime, long endTime)
{
	assert(endTime >= startTime, "endTime must be greater than startTime");
	size_t first = events.GetNextEventByTime(startTime);
	size_t last = events.GetNextEventByTime(endTime+1);
	if(first == -1)
		return events[$..$];
	else if(last == -1)
		return events[first..$];
	else
		return events[first..last];
}
