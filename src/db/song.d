module db.song;

import db.instrument;
import db.sequence;
import db.player;
import db.tools.range;
import db.tools.midifile;
import db.tools.guitarprofile;
import db.scorekeepers.drums;

import fuji.fuji;
import fuji.material;
import fuji.sound;
import fuji.filesystem;

import std.conv : to;
import std.range: back, empty;
import std.algorithm;
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

	private GHVersion DetectVersion(MIDIFile midi)
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
			MIDIEvent*[128][16] currentNotes;
			Event*[128][16] currentEvents;
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

	bool LoadRawMidi(MIDIFile midi)
	{
		if(midi.format != 1)
		{
			MFDebug_Warn(2, "Unsupported midi format!".ptr);
			return false;
		}

		resolution = midi.ticksPerBeat;

		auto tracks = midi.tracks;

		foreach(track, events; tracks)
		{
			Part part;
			bool bIsEventTrack = true;
			SongPart* pPart;
			Variation* pVariation;

			// detect which track we're looking at
			if(track == 0)
			{
				// is sync track
			}
			else
			{
				// search for channel 9; drums
				bool bDrums = canFind!((a) => a.type == MIDIEventType.NoteOn && a.note.channel == 9)(events);

				// search for lyrics; vox
				bool bVox = !bDrums && canFind!((a) => a.isEvent(MIDIEvents.Lyric))(events);
				
				if(bDrums)
				{
					part = Part.Drums;
					pPart = &parts[part];
					pPart.part = part;
					pPart.variations ~= Variation("Track " ~ to!string(track + 1) ~ "-7drums");
					pVariation = &pPart.variations[$-1];

					Sequence seq = new Sequence();
					seq.part = part;
					seq.variation = pVariation.name;
					seq.difficulty = "Expert";
					pVariation.difficulties ~= seq;
				}
				else if(bVox)
				{
					part = Part.Vox;
				}
			}

			// parse the events
			MIDIEvent*[128][16] currentNotes;
			Event*[128][16] currentEvents;
			foreach(ref e; events)
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

							if(part == Part.Unknown)
							{
								// stash it in the events track
								ev.event = EventType.Event;
								ev.text = text;
								this.events ~= ev;
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

				if(e.type != MIDIEventType.NoteOff && e.type != MIDIEventType.NoteOn)
				{
					MFDebug_Warn(2, "Unexpected event: " ~ to!string(e.type));
					continue;
				}
				if(e.type == MIDIEventType.NoteOff || (e.type == MIDIEventType.NoteOn && e.note.velocity == 0))
				{
					if(currentNotes[channel][note] == null)
					{
						MFDebug_Warn(2, "Note already up: " ~ to!string(note));
						continue;
					}

					// calculate and set note duration that this off event terminates
					int duration = e.tick - currentNotes[channel][note].tick;

					// Note: 240 (1/8th) seems like an established minimum sustain
					if(part != Part.Drums && duration >= 240 && currentEvents[channel][note])
						currentEvents[channel][note].duration = duration;

					currentNotes[channel][note] = null;
					currentEvents[channel][note] = null;
					continue;
				}
				if(e.type == MIDIEventType.NoteOn)
				{
					if(currentNotes[channel][note] != null)
						MFDebug_Warn(2, "Note already down: " ~ to!string(note));

					currentNotes[channel][note] = &e;
				}

				switch(part) with(Part)
				{
					case Drums:
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
							{ DrumNotes.Crash, 0 }, //52 Chinese Cymbal
							{ DrumNotes.Ride, MFBit!(DrumNoteFlags.CymbalBell) }, //53 Ride Bell
							{ -1, 0 },//DrumNotes.Cowbell, 0 }, //54 Tambourine
							{ DrumNotes.Crash, 0 }, //55 Splash Cymbal
							{ -1, 0 },//DrumNotes.Cowbell, 0 }, //56 Cowbell
							{ DrumNotes.Crash, 0 }, //57 Crash Cymbal 2
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
						if(drumMap[n].note != -1)
						{
							ev.event = EventType.Note;
							ev.note.key = drumMap[n].note;
							ev.note.flags = drumMap[n].flags;

							pVariation.difficulties[0].notes ~= ev;
							currentEvents[channel][note] = &pVariation.difficulties[0].notes.back;
						}

						break;
					case Vox:
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

	bool LoadGPx(GuitarProFile gpx)
	{
		// TODO: what can we parse from a GP file?

		// parse timing

		// parse drums

		// parse 'real' guitar and bass

		// parse keyboard

		// parse lyrics/vox

		return false;
	}

	bool LoadSM(const(char)[] sm)
	{
		// Format description:
		// http://www.stepmania.com/wiki/The_.SM_file_format

		enum SMResolution = 48;
		resolution = SMResolution;

		while(1)
		{
			auto start = sm.find('#');
			if(!start)
				break;
			size_t split = start.countUntil(':');
			if(split == -1)
				break;

			// get the tag
			auto tag = start[1..split];

			auto end = countUntil(start[split..$], ";");
			if(end == -1)
				break;

			// get the content
			auto content = start[split+1..split+end];
			sm = start[split+end+1..$];

			if(!content.length)
				continue;

			switch(tag)
			{
				case "TITLE":
					name = content.idup;
					break;
				case "SUBTITLE":
					subtitle = content.idup;
					break;
				case "ARTIST":
					artist = content.idup;
					break;
				case "TITLETRANSLIT":
					params[tag] = content.idup;
					break;
				case "SUBTITLETRANSLIT":
					params[tag] = content.idup;
					break;
				case "ARTISTTRANSLIT":
					params[tag] = content.idup;
					break;
				case "CREDIT":
					charterName = content.idup;
					break;
				case "BANNER":
					cover = content.idup;
					break;
				case "BACKGROUND":
					background = content.idup;
					break;
				case "LYRICSPATH":
					params[tag] = content.idup;
					break;
				case "CDTITLE":
					params[tag] = content.idup;
					break;
				case "MUSIC":
					musicFiles[MusicFiles.Song] = content.idup;
					break;
				case "OFFSET":
					startOffset = cast(long)(to!double(content)*1_000_000);
					break;
				case "SAMPLESTART":
					params[tag] = content.idup;
					break;
				case "SAMPLELENGTH":
					params[tag] = content.idup;
					break;
				case "SELECTABLE":
					params[tag] = content.idup;
					break;
				case "BPMS":
					Event ev;
					ev.tick = 0;

					// we need to write a time signature first...
					ev.event = EventType.TimeSignature;
					ev.ts.numerator = 4;
					ev.ts.denominator = 4;
					sync ~= ev;

					auto bpms = content.splitter(',');
					foreach(b; bpms)
					{
						auto params = b.findSplit("=");
						double offset = to!double(params[0]);
						double bpm = to!double(params[2]);

						ev.tick = cast(int)(offset*cast(double)SMResolution);
						ev.event = EventType.BPM;
						ev.bpm.usPerBeat = cast(int)(60_000_000.0 / bpm + 0.5);
						sync ~= ev;
					}
					break;
				case "DISPLAYBPM":
					// a    - BPM stays set at 'a' value (no cycling)
					// a:b  - BPM cycles between 'a' and 'b' values
					// *    - BPM cycles randomly
					params[tag] = content.idup;
					break;
				case "STOPS":
					auto freezes = content.splitter(',');
					foreach(f; freezes)
					{
						auto params = f.findSplit("=");
						double offset = to!double(params[0]);
						double seconds = to!double(params[2]);

						Event ev;
						ev.tick = cast(int)(offset*SMResolution);
						ev.event = EventType.Freeze;
						ev.freeze.usToFreeze = cast(long)(seconds*1_000_1000);
						sync ~= ev;
					}
					break;
				case "BGCHANGE":
					params[tag] = content.idup;
					break;
			case "NOTES":
					auto parts = content.splitter(':');
					auto type = parts.front.strip; parts.popFront;
					auto desc = parts.front.strip; parts.popFront;
					auto difficulty = parts.front.strip; parts.popFront;
					auto meter = parts.front.strip; parts.popFront;
					auto radar = parts.front.strip; parts.popFront;

					Sequence seq = new Sequence;
					seq.part = Part.Dance;
					seq.variation = type.idup;
					seq.difficulty = difficulty.idup;
					seq.difficultyMeter = to!int(meter);

					// TODO: do something with desc?
					// TODO: do something with the radar values?

					// generate note map
					const(int)[] map;
					with(DanceNotes)
					{
						__gshared immutable int[4] mapDanceSingle	= [ Left,Down,Up,Right ];
						__gshared immutable int[8] mapDanceDouble	= [ Left,Down,Up,Right,Left2,Down2,Up2,Right2 ];
						__gshared immutable int[8] mapDanceCouple	= [ Left,Down,Up,Right,Left2,Down2,Up2,Right2 ];
						__gshared immutable int[6] mapDanceSolo		= [ Left,UpLeft,Down,Up,UpRight,Right ];
						__gshared immutable int[5] mapPumpSingle	= [ DownLeft,UpLeft,Center,UpRight,DownRight ];
						__gshared immutable int[10] mapPumpDouble	= [ DownLeft,UpLeft,Center,UpRight,DownRight,DownLeft2,UpLeft2,Center2,UpRight2,DownRight2 ];
						__gshared immutable int[10] mapPumpCouple	= [ DownLeft,UpLeft,Center,UpRight,DownRight,DownLeft2,UpLeft2,Center2,UpRight2,DownRight2 ];
						__gshared immutable int[5] mapEz2Single		= [ UpLeft,LeftHand,Down,RightHand,UpRight ];
						__gshared immutable int[10] mapEz2Double	= [ UpLeft,LeftHand,Down,RightHand,UpRight,UpLeft2,LeftHand2,Down2,RightHand2,UpRight2 ];
						__gshared immutable int[7] mapEz2Real		= [ UpLeft,LeftHandBelow,LeftHand,Down,RightHand,RightHandBelow,UpRight ];
						__gshared immutable int[5] mapParaSingle	= [ Left,UpLeft,Up,UpRight,Right ];

						switch(type)
						{
							case "dance-single":	map = mapDanceSingle; 	break;
							case "dance-double":	map = mapDanceDouble; 	break;
							case "dance-couple":	map = mapDanceCouple; 	break;
							case "dance-solo":		map = mapDanceSolo;		break;
							case "pump-single":		map = mapPumpSingle;	break;
							case "pump-double":		map = mapPumpDouble;	break;
							case "pump-couple":		map = mapPumpCouple;	break;
							case "ez2-single":		map = mapEz2Single;		break;
							case "ez2-double":		map = mapEz2Double;		break;
							case "ez2-real":		map = mapEz2Real;		break;
							case "para-single":		map = mapParaSingle;	break;
							default: break;
						}
					}

					// break into measures
					auto measures = parts.front.strip.splitter(',');

					// read notes...
					ptrdiff_t[10] holds = -1;

					int offset;
					foreach(m; measures)
					{
						auto lines = m.strip.splitLines;
						if(lines[0].length < map.length || lines[0][0..2] == "//")
							lines = lines[1..$];

						int step = SMResolution*4 / cast(int)lines.length;

						foreach(int i, line; lines)
						{
							foreach(n, note; line.strip[0..map.length])
							{
								if(note == '3')
								{
									// set the duration for the last freeze arrow
									seq.notes[holds[n]].duration = offset + i*step - seq.notes[holds[n]].tick;
									holds[n] = -1;
								}
								else if(note != '0')
								{
									Event ev;
									ev.tick = offset + i*step;
									ev.event = EventType.Note;
									ev.note.key = map[n];

									if(note != '1')
									{
										if(note == '2' || note == '4')
											holds[n] = seq.notes.length;

										if(note == '4')
											ev.note.flags |= MFBit!(DanceFlags.Roll);
										else if(note == 'M')
											ev.note.flags |= MFBit!(DanceFlags.Mine);
										else if(note == 'L')
											ev.note.flags |= MFBit!(DanceFlags.Lift);
										else if(note == 'F')
											ev.note.flags |= MFBit!(DanceFlags.Fake);
										else if(note == 'S')
											ev.note.flags |= MFBit!(DanceFlags.Shock);
										else if(note >= 'a' && note <= 'z')
										{
											ev.note.flags |= MFBit!(DanceFlags.Sound);
											ev.note.flags |= (note - 'a') << 24;
										}
										else if(note >= 'A' && note <= 'Z')
										{
											ev.note.flags |= MFBit!(DanceFlags.Sound);
											ev.note.flags |= (note - 'A' + 26) << 24;
										}
									}

									seq.notes ~= ev;
								}
							}
						}

						offset += SMResolution*4;
					}

					// find variation for tag, if there isn't one, create it.
					Variation* pVariation = GetVariation(Part.Dance, type, true);

					// create difficulty, set difficulty to feet rating
					assert(!GetDifficulty(*pVariation, difficulty), "Difficulty already exists!");
					pVariation.difficulties ~= seq;
					break;

				default:
					MFDebug_Warn(2, "Unknown tag: " ~ tag);
					break;
			}
		}

		// since freezes and bpm changes are added at different times, they need to be sorted
		sync.sort!("a.tick < b.tick");

		return false;
	}

	bool LoadDWI(const(char)[] dwi)
	{
		// Format description:
		// http://dwi.ddruk.com/readme.php#4

		enum DwiResolution = 48;
		resolution = DwiResolution;

		while(1)
		{
			auto start = dwi.find('#');
			if(!start)
				break;
			size_t split = start.countUntil(':');
			if(split == -1)
				break;

			// get the tag
			auto tag = start[1..split];

			string term = tag[] == "BACKGROUND" ? "#END;" : ";";
			auto end = countUntil(start[split..$], term);
			if(end == -1)
				break;

			// get the content
			auto content = start[split+1..split+end];
			dwi = start[split+end+term.length..$];

			switch(tag)
			{
				case "TITLE":			// #TITLE:...;  	 title of the song.
					name = content.idup;
					break;
				case "ARTIST":			// #ARTIST:...;  	 artist of the song.
					artist = content.idup;
					break;

					// Special Characters are denoted by giving filenames in curly-brackets.
					//   eg. #DISPLAYTITLE:The {kanji.png} Song;
					// The extra character files should be 50 pixels high and be black-and-white. The baseline for the font should be 34 pixels from the top.
				case "DISPLAYTITLE":	// #DISPLAYTITLE:...;  	 provides an alternate version of the song name that can also include special characters.
					// TODO...
					break;
				case "DISPLAYARTIST":	// #DISPLAYARTIST:...; 	 provides an alternate version of the artist name that can also include special characters.
					// TODO...
					break;

				case "GAP":				// #GAP:...;  	 number of milliseconds that pass before the program starts counting beats. Used to sync the steps to the music.
					startOffset = to!long(content)*1_000;
					break;
				case "BPM":				// #BPM:...;  	 BPM of the music
					Event ev;
					ev.tick = 0;

					// we need to write a time signature first...
					ev.event = EventType.TimeSignature;
					ev.ts.numerator = 4;
					ev.ts.denominator = 4;
					sync ~= ev;

					// set the starting BPM
					ev.event = EventType.BPM;
					ev.bpm.usPerBeat = cast(int)(60_000_000.0 / to!double(content) + 0.5);
					sync ~= ev;
					break;
				case "DISPLAYBPM":		// #DISPLAYBPM:...;	tells DWI to display the BPM on the song select screen in a user-defined way.  Options can be:
					// *    - BPM cycles randomly
					// a    - BPM stays set at 'a' value (no cycling)
					// a..b - BPM cycles between 'a' and 'b' values
					// TODO...
					break;
				case "FILE":			// #FILE:...;  	 path to the music file to play (eg. /music/mysongs/abc.mp3 )
					// TODO: check if it exists?
					musicFiles[MusicFiles.Song] = content.idup;
					break;
				case "MD5":				// #MD5:...;  	 an MD5 string for the music file. Helps ensure that same music file is used on all systems.
					break;
				case "FREEZE":			// #FREEZE:...;  	 a value of the format "BBB=sss". Indicates that at 'beat' "BBB", the motion of the arrows should stop for "sss" milliseconds. Turn on beat-display in the System menu to help determine what values to use. Multiple freezes can be given by separating them with commas.
					auto freezes = content.splitter(',');
					foreach(f; freezes)
					{
						auto params = f.findSplit("=");
						double offset = to!double(params[0]);
						double ms = to!double(params[2]);

						Event ev;
						ev.tick = cast(int)(offset*DwiResolution) / 4; // TODO: wtf? why /4?? It's supposed to be in beats!
						ev.event = EventType.Freeze;
						ev.freeze.usToFreeze = cast(long)(ms*1_000);
						sync ~= ev;
					}
					break;
				case "CHANGEBPM":		// #CHANGEBPM:...;  	 a value of the format "BBB=nnn". Indicates that at 'beat' "BBB", the speed of the arrows will change to reflect a new BPM of "nnn". Multiple BPM changes can be given by separating them with commas.
					auto bpms = content.splitter(',');
					foreach(b; bpms)
					{
						auto params = b.findSplit("=");
						double offset = to!double(params[0]);
						double bpm = to!double(params[2]);

						Event ev;
						ev.tick = cast(int)(offset*cast(double)DwiResolution) / 4; // TODO: wtf? why /4?? It's supposed to be in beats!
						ev.event = EventType.BPM;
						ev.bpm.usPerBeat = cast(int)(60_000_000.0 / bpm + 0.5);
						sync ~= ev;
					}
					break;
				case "STATUS":			// #STATUS:...;  	 can be "NEW" or "NORMAL". Changes the display of songs on the song-select screen.
					break;
				case "GENRE":			// #GENRE:...;  	 a genre to assign to the song if "sort by Genre" is selected in the System Options. Multiple Genres can be given by separating them with commas.
					sourcePackageName = content.idup;
					break;
				case "CDTITLE":			// #CDTITLE:...;  	 points to a small graphic file (64x40) that will display in the song selection screen in the bottom right of the background, showing which CD the song is from. The colour of the pixel in the upper-left will be made transparent.
					break;
				case "SAMPLESTART":		// #SAMPLESTART:...;  	 the time in the music file that the preview music should start at the song-select screen. Can be given in Milliseconds (eg. 5230), Seconds (eg. 5.23), or minutes (eg. 0:05.23). Prefix the number with a "+" to factor in the GAP value.
					break;
				case "SAMPLELENGTH":	// #SAMPLELENGTH:...;  	 how long to play the preview music for at the song-select screen. Can be in milliseconds, seconds, or minutes.
					break;
				case "RANDSEED":		// #RANDSEED:x;  	 provide a number that will influence what AVIs DWI picks and their order. Will be the same animation each time if AVI filenames and count doesn't change (default is random each time).
					break;
				case "RANDSTART":		// #RANDSTART:x;  	 tells DWI what beat to start the animations on. Default is 32.
					break;
				case "RANDFOLDER":		// #RANDFOLDER:...;  	 tells DWI to look in another folder when choosing AVIs, allowing 'themed' folders.
					break;
				case "RANDLIST":		// #RANDLIST:...;  	 a list of comma-separated filenames to use in the folder.
					break;
				case "BACKGROUND":		// #BACKGROUND:     ........     #END;
					break;

				case "SINGLE", "DOUBLE", "COUPLE", "SOLO":
					with(DanceNotes)
					{
						enum uint[char] stepMap = [
							'0': 0,
							'1': MFBit!Left | MFBit!Down,
							'2': MFBit!Down,
							'3': MFBit!Down | MFBit!Right,
							'4': MFBit!Left,
							'5': 0,
							'6': MFBit!Right,
							'7': MFBit!Left | MFBit!Up,
							'8': MFBit!Up,
							'9': MFBit!Up | MFBit!Right,
							'A': MFBit!Up | MFBit!Down,
							'B': MFBit!Left | MFBit!Right,
							'C': MFBit!UpLeft,
							'D': MFBit!UpRight,
							'E': MFBit!Left | MFBit!UpLeft,
							'F': MFBit!Down | MFBit!UpLeft,
							'G': MFBit!Up | MFBit!UpLeft,
							'H': MFBit!Right | MFBit!UpLeft,
							'I': MFBit!Left | MFBit!UpRight,
							'J': MFBit!Down | MFBit!UpRight,
							'K': MFBit!Up | MFBit!UpRight,
							'L': MFBit!Right | MFBit!UpRight,
							'M': MFBit!UpLeft | MFBit!UpRight ];

						enum string[string] variationMap = [ "SINGLE":"dance-single", "DOUBLE":"dance-double", "COUPLE":"dance-couple", "SOLO":"dance-solo" ];
						enum string[string] difficultyMap = [ "BEGINNER":"Beginner", "BASIC":"Easy", "ANOTHER":"Medium", "MANIAC":"Hard", "SMANIAC":"Challenge" ];

						auto parts = content.splitter(':');
						auto diff = parts.front.strip; parts.popFront;
						auto meter = parts.front.strip; parts.popFront;
						auto left = parts.front.strip; parts.popFront;
						auto right = parts.empty ? null : parts.front.strip;

						string variation = tag in variationMap ? variationMap[tag] : tag.idup;
						string difficulty = diff in difficultyMap ? difficultyMap[diff] : diff.idup;

						Sequence seq = new Sequence;
						seq.part = Part.Dance;
						seq.variation = variation;
						seq.difficulty = difficulty;
						seq.difficultyMeter = to!int(meter);

						// read notes...
						static void ReadNotes(Sequence seq, const(char)[] steps, int shift)
						{
							int offset;

							int[16] step;
							int depth;
							step[depth] = 8;

							bool bHold;

							ptrdiff_t[9] holds = -1;

							foreach(s; steps)
							{
								switch(s)
								{
									case '(':	step[++depth] = 16;		break;
									case '[':	step[++depth] = 24;		break;
									case '{':	step[++depth] = 64;		break;
									case '`':	step[++depth] = 192;	break;
									case '<':	step[++depth] = 0;		break;
									case ')':
									case ']':
									case '}':
									case '\'':
									case '>':	--depth;				break;
									case '!':	bHold = true;			break;
									default:
										if(bHold)
										{
											// set the notes as holds
											auto pNote = s in stepMap;
											uint note = pNote ? *pNote : 0;

											int lastOffset = seq.notes.back.tick;
											if(note)
											{
												for(int i=0; i<9; ++i)
												{
													if(note & 1<<i)
													{
														for(size_t j=seq.notes.length-1; j>=0 && seq.notes[j].tick == lastOffset; --j)
														{
															if(seq.notes[j].note.key == i+shift)
															{
																holds[i] = j;
																break;
															}
														}
													}
												}
											}
											bHold = false;
										}
										else
										{
											auto pStep = s in stepMap;
											uint note = pStep ? *pStep : 0;
											if(note)
											{
												// produce a note for each bit
												for(int i=0; i<9; ++i)
												{
													if(note & 1<<i)
													{
														if(holds[i] != -1)
														{
															// terminate the hold
															Event* pNote = &seq.notes[holds[i]];
															pNote.duration = offset - pNote.tick;
															holds[i] = -1;
														}
														else
														{
															// place note
															Event ev;
															ev.tick = offset;
															ev.event = EventType.Note;
															ev.note.key = i+shift;
															seq.notes ~= ev;
														}
													}
												}
											}

											offset += DwiResolution*4 / step[depth];
										}
										break;
								}
							}
						}

						ReadNotes(seq, left, 0);
						if(!right.empty)
						{
							ReadNotes(seq, right, DanceNotes.Left2);
							seq.notes.sort!("a.tick < b.tick", SwapStrategy.stable);
						}

						// find variation, if there isn't one, create it.
						Variation* pVariation = GetVariation(Part.Dance, seq.variation, true);

						// create difficulty, set difficulty to feet rating
						assert(!GetDifficulty(*pVariation, seq.difficulty), "Difficulty already exists!");
						pVariation.difficulties ~= seq;
					}
					break;

				default:
					MFDebug_Warn(2, "Unknown tag: " ~ tag);
					break;
			}
		}

		// since freezes and bpm changes are added at different times, they need to be sorted
		sync.sort!("a.tick < b.tick");

		return false;
	}

	bool LoadKSF(const(char)[] ksf, const(char)[] filename)
	{
		// Format description:
		// https://code.google.com/p/sm-ssc/source/browse/Docs/SimfileFormats/KSF/ksf-format.txt?name=stepsWithScore

		const(int)[] panels;

		enum KsfResolution = 48;
		resolution = KsfResolution;

		string type, difficulty;
		bool bParseMetadata;

		with(DanceNotes)
		{
			__gshared immutable int[10] mapPump = [ DownLeft,UpLeft,Center,UpRight,DownRight,DownLeft2,UpLeft2,Center2,UpRight2,DownRight2 ];

			switch(filename)
			{
				case "Easy_1.ksf":
					type = "pump-single";
					difficulty = "Easy";
					panels = mapPump[0..5];
					bParseMetadata = true;
					break;
				case "Hard_1.ksf":
					type = "pump-single";
					difficulty = "Medium";
					panels = mapPump[0..5];
					bParseMetadata = true;
					break;
				case "Crazy_1.ksf":
					type = "pump-single";
					difficulty = "Hard";
					panels = mapPump[0..5];
					bParseMetadata = true;
					break;
				case "Easy_2.ksf":
					type = "pump-couple";
					panels = mapPump;
					difficulty = "Easy";
					break;
				case "Hard_2.ksf":
					type = "pump-couple";
					panels = mapPump;
					difficulty = "Medium";
					break;
				case "Crazy_2.ksf":
					type = "pump-couple";
					panels = mapPump;
					difficulty = "Hard";
					break;
				case "Double.ksf":
					type = "pump-double";
					panels = mapPump;
					difficulty = "Medium";
					break;
				case "CrazyDouble.ksf":
					type = "pump-double";
					panels = mapPump;
					difficulty = "Hard";
					break;
				case "HalfDouble.ksf":
					type = "pump-double";
					panels = mapPump;
					difficulty = "Easy";	// NOTE: Should this be 'Easy', or 'Half'? Is the reduction to make it easier?
					break;
				default:
					MFDebug_Warn(2, "Unknown .ksf file difficulty: " ~ filename);
					return true;
			}
		}

		Sequence seq = new Sequence;
		seq.part = Part.Dance;
		seq.variation = type;
		seq.difficulty = difficulty;

		bool bParseSync = sync.length == 0;
		int step;

		while(1)
		{
			auto start = ksf.find('#');
			if(!start)
				break;
			size_t split = start.countUntil(':');
			if(split == -1)
				break;

			// get the tag
			auto tag = start[1..split];
			auto end = countUntil(start[split..$], ";");

			// get the content
			const(char)[] content;
			if(end != -1)
			{
				content = start[split+1 .. split+end];
				ksf = start[split+end+1..$];
			}
			else
			{
				content = start[split+1 .. $];
				ksf = null;
			}

			switch(tag)
			{
				case "TITLE":
					// We take it from the folder name; some difficulties of some songs seem to keep junk in #TITLE
					if(bParseMetadata)
					{
						// "Artist - Title"
//						name = content.idup;
					}
					break;
				case "STARTTIME":
					// this may be different for each chart... which means each chart sync's differently.
					// TODO: we need to convert differing offsets into extra measures with no steps.
					long offset = cast(long)(to!double(content)*10_000.0);
					if(startOffset != 0 && startOffset != offset)
					{
						MFDebug_Warn(2, "#STARTTIME doesn't match other .ksf files in: " ~ filename);

						if(offset < startOffset)
						{
							// TODO: add extra measures, push existing notes forward
						}
						else if(offset > startOffset)
						{
							// TODO: calculate an offset to add to all notes that we parse on this chart
							// ie, find the tick represented by this offset - startOffset.
						}
					}
					startOffset = offset;
					break;
				case "TICKCOUNT":
					step = resolution / to!int(content);
					break;
				case "DIFFICULTY":
					seq.difficultyMeter = to!int(content);
					break;
				default:
					// BPM/BUNKI
					if(tag == "BPM")
					{
						if(bParseSync)
						{
							Event ev;
							ev.tick = 0;

							// we need to write a time signature first...
							ev.event = EventType.TimeSignature;
							ev.ts.numerator = 4;
							ev.ts.denominator = 4;
							sync ~= ev;

							// set the starting BPM
							ev.event = EventType.BPM;
							ev.bpm.usPerBeat = cast(int)(60_000_000.0 / to!double(content) + 0.5);
							sync ~= ev;
						}
						else
						{
							// TODO: validate that it matches the previously parsed data?
							if(sync[1].bpm.usPerBeat != cast(int)(60_000_000.0 / to!double(content) + 0.5))
								MFDebug_Warn(2, "#BPM doesn't match other .ksf files in: " ~ filename);
						}
					}
					else if(tag.length > 3 && tag[0..3] == "BPM")
					{
						if(bParseSync)
						{
							int index = tag[3] - '0';

							while(sync.length <= index)
							{
								Event ev;
								ev.event = EventType.BPM;
								sync ~= ev;
							}

							sync[index].bpm.usPerBeat = cast(int)(60_000_000.0 / to!double(content) + 0.5);
						}
						else
						{
							// TODO: validate that it matches the previously parsed data?
						}
					}
					else if(tag.length >= 5 && tag[0..5] == "BUNKI")
					{
						if(bParseSync)
						{
							int index = tag.length > 5 ? tag[5] - '0' + 1 : 2;

							while(sync.length <= index)
							{
								Event ev;
								ev.event = EventType.BPM;
								sync ~= ev;
							}

							long time = cast(long)(to!double(content) * 10_000.0);
							sync[index].tick = CalculateTickAtTime(time);
						}
						else
						{
							// TODO: validate that it matches the previously parsed data?
						}
					}
					else
					{
						MFDebug_Warn(2, "Unknown tag: " ~ tag);
					}
					break;

				case "STEP":
					content = content.strip;

					ptrdiff_t[10] holds = -1;

					auto lines = content.splitLines;
					foreach(int i, l; lines)
					{
						if(l[0] == '2')
							break;

						int offset = i*step;
						for(int j=0; j<panels.length; ++j)
						{
							if(l[j] == '0')
							{
								holds[j] = -1;
							}
							else
							{
								if(l[j] == '1' || l[j] == '4' && holds[j] == -1)
								{
									// place note
									Event ev;
									ev.tick = offset;
									ev.event = EventType.Note;
									ev.note.key = panels[j];
									seq.notes ~= ev;
								}
								if(l[j] == '4')
								{
									if(holds[j] == -1)
										holds[j] = seq.notes.length-1;
									else
										seq.notes[holds[j]].duration = offset - seq.notes[holds[j]].tick;
								}
							}
						}
					}
					break;
			}
		}

		// find variation, if there isn't one, create it.
		Variation* pVariation = GetVariation(Part.Dance, seq.variation, true);

		// create difficulty, set difficulty to feet rating
		assert(!GetDifficulty(*pVariation, seq.difficulty), "Difficulty already exists!");
		pVariation.difficulties ~= seq;

		return false;
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
			CalculateNoteTimes(p.events, 0);
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

	Variation* GetVariation(Part part, const(char)[] variation, bool bCreate = false)
	{
		SongPart* pPart = &parts[part];
		foreach(ref v; pPart.variations)
		{
			if(!variation || (variation && v.name[] == variation))
				return &v;
		}
		if(bCreate)
		{
			pPart.variations ~= Variation(variation.idup);
			return &pPart.variations.back;
		}
		return null;
	}

	Sequence GetDifficulty(ref Variation variation, const(char)[] difficulty)
	{
		foreach(d; variation.difficulties)
		{
			if(d.difficulty[] == difficulty)
				return d;
		}
		return null;
	}

	Sequence GetSequence(Player player, const(char)[] variation, const(char)[] difficulty)
	{
		Part part = player.input.part;
		SongPart* pPart = &parts[part];
		if(pPart.variations.empty)
			return null;

		Variation* var;
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
				foreach(ref v; pPart.variations)
				{
					if(endsWith(v.name, pref))
					{
						if(!variation || (variation && startsWith(v.name, variation)))
						{
							var = &v;
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
			foreach(ref v; pPart.variations)
			{
				if(!variation || (variation && v.name == variation))
				{
					var = &v;
					bFound = true;
					break;
				}
			}
		}

		if(!bFound)
			return null;

		Sequence s;
		if(difficulty)
			s = GetDifficulty(*var, difficulty);

		// TODO: should there be some fallback logic if a requested difficulty isn't available?
		//       can we rank difficulties by magic name strings?
		if(!s)
			s = var.difficulties.back;

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
	string subtitle;
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
	string video;

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
	while(true)
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
		if(!topBit)
			break;
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
ptrdiff_t SkipEvents(bool reverse = false, Types...)(Event[] events, ptrdiff_t e, Types types) if(AllIs!(E.EventType, Types))
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
