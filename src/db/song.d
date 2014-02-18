module db.song;

import db.instrument;
import db.sequence;
import db.player;
import db.tools.midifile;
import db.scorekeepers.drums;

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

enum DrumsType
{
	Unknown = -1,

	FourDrums = 0,
	FiveDrums,
	SevenDrums
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

	bool bHasCoopMarkers;		// GH1/GH2 style co-op (players take turns)
}

class Song
{
	this()
	{
	}

	bool Load(string filename = null)
	{
		return false;
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

	bool LoadMidi(MIDIFile midi, GHVersion ghVer = GHVersion.Unknown)
	{
		__gshared immutable auto difficulties = [ "Easy", "Medium", "Hard", "Expert" ];

		if(midi.format != 1)
		{
			MFDebug_Warn(2, "Unsupported midi format!".ptr);
			return false;
		}

		if(ghVer == GHVersion.Unknown)
			ghVer = DetectVersion(midi);

		resolution = midi.ticksPerBeat;

		foreach(i, t; midi.tracks)
		{
			auto name = t.getFront();
			while(!name.isEvent(MIDIEvents.TrackName))
				name = t.getFront();

			if(!name.isEvent(MIDIEvents.TrackName))
			{
				MFDebug_Warn(2, "Expected track name.".ptr);
				return false;
			}

			Part part;
			bool bIsEventTrack = true;
			SongPart* pPart;
			Variation* pVariation;

			DrumsType drumType = DrumsType.Unknown;
			int difficulty = -1;

			// detect which track we're looking at
			if(i == 0)
			{
				MFDebug_Log(3, "Track: SYNC".ptr);
				id = name.text;
			}
			else
			{
				MFDebug_Log(3, "Track: " ~ name.text);

				string variation = name.text;

				switch(name.text)
				{
					case "T1 GEMS":				variation = "PART GUITAR"; goto case "PART GUITAR";
					case "PART GUITAR":
					case "PART GUITAR COOP":	part = Part.LeadGuitar; bIsEventTrack = false; break;
					case "PART RHYTHM":			part = Part.RhythmGuitar; bIsEventTrack = false; break;
					case "PART BASS":			part = Part.Bass; bIsEventTrack = false; break;
					case "PART DRUMS":			part = Part.Drums; bIsEventTrack = false; break;
					case "PART KEYS":			part = Part.Keys; bIsEventTrack = false; break;

					case "PART VOCALS":
					case "HARM1":
					case "HARM2":
					case "HARM3":				part = Part.Vox; bIsEventTrack = false; break;

					case "PART REAL_GUITAR":
					case "PART REAL_GUITAR_22":	part = Part.ProGuitar; bIsEventTrack = false; break;
					case "PART REAL_BASS":
					case "PART REAL_BASS_22":	part = Part.ProBass; bIsEventTrack = false; break;

					case "PART REAL_KEYS_X":	difficulty = 3; goto case "PART REAL_KEYS";
					case "PART REAL_KEYS_H":	difficulty = 2; goto case "PART REAL_KEYS";
					case "PART REAL_KEYS_M":	difficulty = 1; goto case "PART REAL_KEYS";
					case "PART REAL_KEYS_E":	difficulty = 0; goto case "PART REAL_KEYS";
					case "PART REAL_KEYS":
						variation = "PART REAL_KEYS";
						part = Part.ProKeys;
						bIsEventTrack = false;
						break;

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
					case "PART KEYS_ANIM_RH":
					case "PART KEYS_ANIM_LH":
						// Contains keyboard animation events.
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
					pPart = &parts[part];

					// find variation...
					bool bFound;
					foreach(j, v; pPart.variations)
					{
						if(v.name == variation)
						{
							pVariation = &pPart.variations[j];
							bFound = true;
							break;
						}
					}

					if(!bFound)
					{
						ptrdiff_t v = pPart.variations.length;
						pPart.variations ~= Variation(variation);
						pVariation = &pPart.variations[v];

						// Note: Vox track only has one difficulty...
						pVariation.difficulties = new Sequence[part == Part.Vox ? 1 : difficulties.length];
						foreach(j, ref d; pVariation.difficulties)
						{
							d = new Sequence;
							d.part = part;
							d.variation = variation;
							d.difficulty = part == Part.Vox ? "Default" : difficulties[j];
							d.difficultyMeter = 0; // TODO: I think we can pull this from songs.ini?
						}

						if(part == Part.Drums)
						{
							// scan for any notes 100-102 (indicates pro drums)
							foreach(ref e; t)
							{
								if(e.type == MIDIEventType.NoteOn && e.note.note >= 110 && e.note.note <= 112)
								{
									drumType = DrumsType.SevenDrums;
									break;
								}
							}
							if(drumType == DrumsType.Unknown)
							{
								// check if 'five_lane_drums' appears in song.ini
								string* p5Lane = "five_lane_drums" in params;
								bool b5Lane = p5Lane && (*p5Lane == "1" || !icmp(*p5Lane, "true"));
								if(b5Lane)
									drumType = DrumsType.FiveDrums;
								else
									drumType = DrumsType.FourDrums;
							}

							// prepend the drums type to the variation name
							static __gshared immutable string variationNames[] = [ "-4drums", "-5drums", "-7drums" ];
							pVariation.name = pVariation.name ~ variationNames[drumType];
							foreach(d; pVariation.difficulties)
								d.variation = pVariation.name;
						}
					}
				}
			}

			// parse the events
			MIDIEvent*[128][15] currentNotes;
			Event*[128][15] currentEvents;
			int[3] tomSwitchStart;
			foreach(ref e; t)
			{
				Event ev;
				ev.tick = e.tick;

				int note = e.note.note;
				int channel = e.note.channel;

				if(e.type == MIDIEventType.Custom)
				{
					switch(e.subType) with(MIDIEvents)
					{
						// sync track events
						case TimeSignature:
							assert(e.timeSignature.clocks == 24 && e.timeSignature.d == 8, "Unexpected!");

							ev.event = EventType.TimeSignature;
							ev.ts.numerator = e.timeSignature.numerator;
							ev.ts.denominator = 1 << e.timeSignature.denominator;
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
								pPart.events ~= ev;
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
							pVariation.difficulties[0].notes ~= ev;
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
					if(part == Part.Drums && note >= 110 && note <= 112)
					{
						// RB: tom's instead of cymbals
						int start = tomSwitchStart[note - 110];
						if(start != 0)
						{
							tomSwitchStart[note - 110] = 0;

							foreach(seq; pVariation.difficulties)
							{
								Event[] notes = seq.notes;
								for(ptrdiff_t j = notes.length-1; j >= 0 && notes[j].tick >= start; --j)
								{
									Event *pEv = &notes[j];
									if(pEv.event != EventType.Note)
										continue;

									switch(pEv.note.key) with(DrumNotes)
									{
										case Hat:	pEv.note.key = Tom1; break;
										case Ride:	pEv.note.key = Tom2; break;
										case Crash:	pEv.note.key = Tom3; break;
										default:	break;
									}
								}
							}
						}
					}

					if(currentNotes[channel][note] == null)
					{
						MFDebug_Warn(2, "[" ~ name.text ~ "] Note already up: " ~ to!string(note));
						continue;
					}

					// calculate and set note duration that this off event terminates
					int duration = e.tick - currentNotes[channel][note].tick;

					// Note: allegedly, in GH1, notes less than 161 length were rejected...
//					if(ghVer == GHVersion.GH && duration < 161 && !bIsEventTrack && currentEvents[channel][note])
//					{
//						MFDebug_Warn(2, "[" ~ name.text ~ "] Note is invalid, must be removed: " ~ to!string(note));
//					}

					// Note: 240 (1/8th) seems like an established minimum sustain
					if(duration >= 240 && currentEvents[channel][note])
						currentEvents[channel][note].duration = duration;

					currentNotes[channel][note] = null;
					currentEvents[channel][note] = null;
					continue;
				}
				if(e.type == MIDIEventType.NoteOn)
				{
					if(currentNotes[channel][note] != null)
						MFDebug_Warn(2, "[" ~ name.text ~ "] Note already down: " ~ to!string(note));

					currentNotes[channel][note] = &e;
				}
				if(bIsEventTrack)
				{
/*
					// TODO: event track notes mean totally different stuff (scene/player animation, etc)
					ev.event = EventType.MIDI;
					ev.midi.type = e.type;
					ev.midi.subType = e.subType;
					ev.midi.channel = e.note.channel;
					ev.midi.note = note;
					ev.midi.velocity = e.note.velocity;
					if(part != Part.Unknown)
					{
						pPart.events ~= ev;
						currentEvents[channel][note] = &pPart.events.back;
					}
					else
					{
						events ~= ev;
						currentEvents[channel][note] = &events.back;
					}
*/
					continue;
				}

				switch(part) with(Part)
				{
					case LeadGuitar, RhythmGuitar, Bass, Drums, Keys:
						switch(note)
						{
							case 12: .. case 15:
								// RB: h2h camera cuts and focus notes
								goto midi_event;

							case 20:
								// unknown!
								goto midi_event;

							case 24: .. case 59:
								switch(part) with(Part)
								{
									case LeadGuitar, RhythmGuitar, Bass:
										if(note >= 40 && note <= 59)
										{
											// RB - guitars: neck position
											ev.event = EventType.NeckPosition;
											ev.position = note - 40;
											goto add_event;
										}
										else if(note >= 30 && note <= 32)
										{
											// unknown!
											goto midi_event;
										}
										break;

									case Drums:
										if(note >= 24 && note <= 51)
										{
											// RB - drums: animation
											ev.event = EventType.DrumAnimation;
											ev.drumAnim = cast(DrumAnimation)(note - 24);
											goto add_event;
										}
										break;

									default:
								}
								goto default;

							case 60: .. case 107:
								// difficulty based notes
								difficulty = (note - 60) / 12;

								int key = note % 12;
								switch(key)
								{
									case 0: .. case 4:
										ev.event = EventType.Note;
										ev.note.key = key;

										if(part == Drums)
										{
											static __gshared immutable int fourDrumMap[5] = [ DrumNotes.Kick, DrumNotes.Snare, DrumNotes.Tom1, DrumNotes.Tom2, DrumNotes.Tom3 ];
											static __gshared immutable int fiveDrumMap[5] = [ DrumNotes.Kick, DrumNotes.Snare, DrumNotes.Hat, DrumNotes.Tom2, DrumNotes.Tom3 ];
											static __gshared immutable int sevenDrumMap[5] = [ DrumNotes.Kick, DrumNotes.Snare, DrumNotes.Hat, DrumNotes.Ride, DrumNotes.Crash ];

											switch(drumType) with(DrumsType)
											{
												case FourDrums:		ev.note.key = fourDrumMap[key]; break;
												case FiveDrums:		ev.note.key = fiveDrumMap[key]; break;
												case SevenDrums:	ev.note.key = sevenDrumMap[key]; break;
												default:
													assert(false, "Unreachable?");
											}
										}
										goto current_difficulty;

									case 5:
										if(part == Part.Drums && drumType == DrumsType.FiveDrums)
										{
											ev.event = EventType.Note;
											ev.note.key = DrumNotes.Ride;
											goto current_difficulty;
										}
										else
										{
											// forced strum?
										}
										break;

									case 6:
										// forced pick
										break;

									case 7:
										ev.event = EventType.Special;
										ev.special = ghVer >= GHVersion.RB ? SpecialType.Solo : SpecialType.Boost;
										goto current_difficulty;

									case 8:
										// unknown?!
										break;

									case 9:
										ev.event = EventType.Special;
										ev.special = SpecialType.LeftPlayer;
										pVariation.bHasCoopMarkers = true;
										if(ghVer >= GHVersion.RB)
											goto all_difficulties;
										goto current_difficulty;

									case 10:
										ev.event = EventType.Special;
										ev.special = SpecialType.RightPlayer;
										pVariation.bHasCoopMarkers = true;
										if(ghVer >= GHVersion.RB)
											goto all_difficulties;
										goto current_difficulty;

									case 11:
										// unknown?!
										break;

									default:
										// unreachable...
										break;
								}
								break;

							case 108:
								// GH1: singer mouth open/close
								if(ghVer == GHVersion.GH)
								{
									// TODO: this needs to be an event with duration...
									ev.event = EventType.Event;
									ev.text = "open_mouth";
									parts[Part.Vox].events ~= ev;
									currentEvents[channel][note] = &parts[Part.Vox].events.back;
									continue;
								}
								goto default;

							case 110:
								if(ghVer == GHVersion.GH2)
								{
									// GH2: unknown guitar event
//										ev.event = ???; break;
									goto midi_event;
								}
								goto case;
							case 111: .. case 112:
								if(part == Part.Drums)
								{
									// RB: tom's instead of cymbals
									tomSwitchStart[note-110] = e.tick;
									continue;
								}
								goto default;

							case 116:
								ev.event = EventType.Special;
								ev.special = SpecialType.Boost;
								goto all_difficulties;

							case 120: .. case 123:	// RB: drum fills
								// Note: Freestyle always triggers all notes from 120-124, so we'll ignore 120-123.
								break;
							case 124:
								ev.event = EventType.Special;
								ev.special = SpecialType.FreeStyle;
								goto all_difficulties;

							case 126, 127:
								switch(part) with(Part)
								{
									case LeadGuitar, RhythmGuitar, Bass, Keys:
										// tremolo
										ev.event = EventType.Special;
										ev.special = note == 126 ? SpecialType.Tremolo : SpecialType.Trill;
										goto all_difficulties;

									case Drums:
										// drum rolls
										ev.event = EventType.Special;
										ev.special = note == 126 ? SpecialType.DrumRoll : SpecialType.SpecialDrumRoll;
										goto all_difficulties;

									default:
								}
								goto default;

							default:
								// TODO: there are still a bunch of unknown notes...
								MFDebug_Warn(2, "[" ~ name.text ~ "] Unknown note: " ~ to!string(note));
								goto midi_event;
						}
						break;

					case ProGuitar, ProRhythmGuitar, ProBass:
						// pro guitar info: http://rockband.scorehero.com/forum/viewtopic.php?t=33322&postdays=0&postorder=asc&start=0
						switch(note)
						{
							case 0: .. case 20:
								// chord names..
								ev.event = EventType.Chord;
								ev.chord = note;
								goto add_event;

							case 21, 45, 69, 93:
								// unknown... (apparently difficulty based)
								goto midi_event;

							case 24: .. case 35:
							case 48: .. case 59:
							case 72: .. case 83:
							case 96: .. case 107:
								difficulty = (note - 24) / 24;

								int n = note % 24;
								switch(n)
								{
									case 0: .. case 5:
										ev.event = EventType.GuitarNote;
										ev.guitar._string = n;
										ev.guitar.fret = e.note.velocity - 100;

										switch(channel)
										{
											case 0:
												// normal note
												break;
											case 1:
												// unknown
												break;
											case 2:
												// bend?
												break;
											case 3:
												ev.guitar.flags |= 1 << GuitarNoteFlags.Mute;
												break;
											case 4:
												// unknown
												break;
											case 5:
												ev.guitar.flags |= 1 << GuitarNoteFlags.Harm;
												break;
											case 6:
												ev.guitar.flags |= 1 << GuitarNoteFlags.ArtificialHarm;
												break;
											default:
												MFDebug_Warn(2, "[" ~ name.text ~ "] Unknown channel: " ~ to!string(channel));
												break;
										}
										goto current_difficulty;

									case 6:
										// hopo
										goto midi_event;

									case 7:
										// slide
										goto midi_event;

									case 8:
										// arpeggio
										goto midi_event;

									case 9:
										// strum direction
										//...

										switch(channel)
										{
											case 13:
												// up strum
												break;
											case 14:
												// middle strum
												break;
											case 15:
												// down strum
												break;
											default:
												MFDebug_Warn(2, "[" ~ name.text ~ "] Unknown channel: " ~ to!string(channel));
												break;
										}
										goto midi_event;

									case 10:
										// unknown
										goto midi_event;

									case 11:
										// unknown
										goto midi_event;

									default:
										break;
								}
								goto default;

							case 108:
								// ?? base note for arpeggio section (velocity determines number)?
								// ?? left hand position?
								goto midi_event;

							case 115, 116:
								ev.event = EventType.Special;
								ev.special = note == 115 ? SpecialType.Solo : SpecialType.Boost;
								goto all_difficulties;

							case 120: .. case 124:	// RB: big rock ending
								// Note: Freestyle always triggers all notes from 120-125, so we'll ignore 120-124.
								break;
							case 125:
								ev.event = EventType.Special;
								ev.special = SpecialType.FreeStyle;
								goto all_difficulties;

							case 126, 127:
								ev.event = EventType.Special;
								ev.special = note == 126 ? SpecialType.Tremolo : SpecialType.Trill;
								goto all_difficulties;

							default:
								// TODO: there are still a bunch of unknown notes...
								MFDebug_Warn(2, "[" ~ name.text ~ "] Unknown note: " ~ to!string(note));
								goto midi_event;
						}

					case ProKeys:
						switch(note)
						{
							case 0: .. case 9:
								// keyboard position
								ev.event = EventType.KeyboardPosition;
								ev.position = Notes.C4 + note;
								goto current_difficulty;

							case Notes.C4: .. case Notes.C6:
								ev.event = EventType.Note;
								ev.note.key = note;
								goto current_difficulty;

							case 115, 116:
								// solo section
								if(difficulty != 3) // these are only meant to appear in the expert chart...
									goto default;

								ev.event = EventType.Special;
								ev.special = note == 115 ? SpecialType.Solo : SpecialType.Boost;
								goto all_difficulties;

							case 126, 127:
								// glissando/trill
								if(difficulty != 3) // these are only meant to appear in the expert chart...
									goto default;

								ev.event = EventType.Special;
								ev.special = note == 126 ? SpecialType.Glissando : SpecialType.Trill;
								goto all_difficulties;

							default:
								// TODO: there are still a bunch of unknown notes...
								MFDebug_Warn(2, "[" ~ name.text ~ "] Unknown note: " ~ to!string(note));
								goto midi_event;
						}

					case Vox:
						// TODO: read vox...
						break;

					default:
						// TODO: there are still many notes in unknown parts...
						break;

					midi_event:
						ev.event = EventType.MIDI;
						ev.midi.type = e.type;
						ev.midi.subType = e.subType;
						ev.midi.channel = e.note.channel;
						ev.midi.note = note;
						ev.midi.velocity = e.note.velocity;
						goto add_event;

					current_difficulty:
						pVariation.difficulties[difficulty].notes ~= ev;
						currentEvents[channel][note] = &pVariation.difficulties[difficulty].notes.back;
						break;

					all_difficulties:
						foreach(seq; pVariation.difficulties)
						{
							seq.notes ~= ev;
							currentEvents[channel][note] = &seq.notes.back;	// TODO: *FIXME* this get's overwritten 4 times, and only the last one will get sustain!
						}
						break;

					add_event:
						pPart.events ~= ev;
						currentEvents[channel][note] = &pPart.events.back;
						break;
				}
			}

			// seven drums may need some post-processing if we have options to rearrange the drums
			if(drumType == DrumsType.SevenDrums)
			{
				// green_is_ride instructs that the crash and ride cymbals should be swapped
				string* pSwapCymbals = "green_is_ride" in params;
				bool bSwapCymbals = pSwapCymbals && (*pSwapCymbals == "1" || !icmp(*pSwapCymbals, "true"));
				if(bSwapCymbals)
				{
					foreach(ref var; parts[Part.Drums].variations)
					{
						foreach(ref d; var.difficulties)
						{
							foreach(ref n; d.notes)
							{
								if(n.event == EventType.Note)
								{
									if(n.note.key == DrumNotes.Crash)
										n.note.key = DrumNotes.Ride;
									else if(n.note.key == DrumNotes.Ride)
										n.note.key = DrumNotes.Crash;
								}
							}
						}
					}
				}
			}
		}

		return true;
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

	Sequence GetSequence(Player player, string variation, string difficulty)
	{
		static Sequence GetDifficulty(Player player, ref Variation variation, string difficulty)
		{
			Sequence s = variation.difficulties.back;
			if(difficulty)
			{
				// TODO: should there be some fallback logic if a requested difficulty isn't available?
				//       can we rank difficulties by magic name strings?

				foreach(d; variation.difficulties)
				{
					if(d.difficulty == difficulty)
					{
						s = d;
						break;
					}
				}
			}
			return s;
		}

		Part part = player.input.part;
		SongPart* pPart = &parts[part];
		if(pPart.variations.empty)
			return null;

		Variation var;
		bool bFound;

		string preferences[];
		size_t preference;

		// TODO: should there be a magic name for the default variation rather than the first one?
		//...

		if(part == Part.Drums)
		{
			// each drums configuration has a different preference for conversion
			if(!(player.input.device.features & MFBit!(DrumFeatures.HasCymbals)))
				preferences = [ "-4drums", "-7drums", "-6drums", "-5drums" ];
			else if(!(player.input.device.features & MFBit!(DrumFeatures.Has3Cymbals)))
			{
				if(!(player.input.device.features & MFBit!(DrumFeatures.Has4Drums)))
					preferences = [ "-5drums", "-6drums", "-7drums", "-4drums" ];
				else
					preferences = [ "-6drums", "-7drums", "-5drums", "-4drums" ];
			}
			else
				preferences = [ "-7drums", "-6drums", "-5drums", "-4drums" ];

			// find the appropriate variation for the player's kit
			outer: foreach(i, pref; preferences)
			{
				foreach(v; pPart.variations)
				{
					if(endsWith(v.name, pref))
					{
						if(!variation || (variation && startsWith(v.name, variation)))
						{
							var = v;
							bFound = true;
							preference = i;
							break outer;
						}
					}
				}
			}
		}
		else
		{
			foreach(v; pPart.variations)
			{
				if(!variation || (variation && v.name == variation))
				{
					var = v;
					bFound = true;
				}
			}
		}

		if(!bFound)
			return null;

		Sequence s = GetDifficulty(player, var, difficulty);

		if(part == Part.Drums && preference != 0)
		{
			// fabricate a sequence for the players kit
			s = FabricateSequence(this, preferences[0], s);
		}

		return s;
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
