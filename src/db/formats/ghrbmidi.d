module db.formats.ghrbmidi;

import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import db.song;
import db.sequence;
import db.instrument;
import db.formats.parsers.midifile;
import db.tools.filetypes;
import db.tools.range;
import db.songlibrary;

import std.string;
import std.encoding;
import std.path;
import std.conv : to;
import std.range : back;

bool LoadGHRBMidi(Track* track, DirEntry file)
{
	Windows1252String ini = cast(Windows1252String)MFFileSystem_Load(file.filepath).assumeUnique;

	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.directory ~ "'");

	MIDIFile midi = new MIDIFile(path ~ "notes.mid");
//	midi.WriteText(path ~ "midi.txt");

	track._song = new Song;
	track._song.params["source_format"] = "ghrb.mid";

	// read song.ini
	string text;
	transcode(ini, text);

	foreach(l; text.splitLines)
	{
		l.strip;
		if(l.empty)
			continue;

		if(l[0] == '[' && l[$-1] == ']')
		{
			// we only know about 'song' sections
			assert(l[1..$-1] == "song", "Expected 'song' section");
		}
		else
		{
			ptrdiff_t equals = l.indexOf('=');
			if(equals == -1)
				continue; // not a key-value pair?

			string key = l[0..equals].strip.toLower;
			string value = l[equals+1..$].strip;

			switch(key)
			{
				case "name":
					// HACK: skip track number...
					if(value.length > 3)
					{
						if(isNumeric(value[0..1]))
						{
							if(value[1] == '.')
								value = value[2..$];
							else if(isNumeric(value[1..2]) && value[2] == '.')
								value = value[3..$];
							value = value.strip;
						}
					}
					track._song.name = value;
					break;
				case "artist":	track._song.artist = value; break;
				case "album":	track._song.album = value; break;
				case "year":	track._song.year = value; break;
				case "genre":	track._song.genre = value; break;
				case "frets":	track._song.charterName = value; break;
				default:
					// unknown values become arbitrary params
					track._song.params[key] = value;
					break;
			}
		}
	}

	// load the midi
	if(!track._song.LoadMidi(midi))
	{
		MFDebug_Warn(2, "Failed to load midi!".ptr);
		return false;
	}

	// search for the music and other stuff...
	Track.Source* src;
	foreach(f; dirEntries(path ~ "*", SpanMode.shallow))
	{
		string filename = f.filename.toLower;
		if(isImageFile(filename))
		{
			switch(filename.stripExtension)
			{
				case "album":		track.coverImage = f.filepath; break;
				case "background":	track.background = f.filepath; break;
				default:
			}
		}
		else if(isAudioFile(filename))
		{
//			static immutable musicFileNames = [ "preview": MusicFiles.Preview ];

			string filepart = filename.stripExtension;
			if(filepart[] == "preview")
				track._preview = f.filepath;
			else if(filepart[] == "rhythm")
			{
				if(!src) src = track.addSource();

				// 'rhythm.ogg' is also be used for bass
				if(track._song.parts[Part.RhythmGuitar].variations)
					src.addStream(f.filepath, Streams.Rhythm);
				else
					src.addStream(f.filepath, Streams.Bass);
			}
			else if(filepart in musicFileNames)
			{
				if(!src) src = track.addSource();
				src.addStream(f.filepath, musicFileNames[filepart]);
			}
		}
	}

	return true;
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

bool LoadMidi(Song song, MIDIFile midi, GHVersion ghVer = GHVersion.Unknown)
{
	with(song)
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
				params["midi_track_name"] = name.text;
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
							static __gshared immutable string[] variationNames = [ "-4drums", "-5drums", "-6drums", "-7drums", "-8drums" ];
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
											static __gshared immutable int[5] fourDrumMap = [ DrumNotes.Kick, DrumNotes.Snare, DrumNotes.Tom1, DrumNotes.Tom2, DrumNotes.Tom3 ];
											static __gshared immutable int[5] fiveDrumMap = [ DrumNotes.Kick, DrumNotes.Snare, DrumNotes.Hat, DrumNotes.Tom2, DrumNotes.Tom3 ];
											static __gshared immutable int[5] sevenDrumMap = [ DrumNotes.Kick, DrumNotes.Snare, DrumNotes.Hat, DrumNotes.Ride, DrumNotes.Crash ];

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
												ev.flags |= 1 << GuitarNoteFlags.Mute;
												break;
											case 4:
												// unknown
												break;
											case 5:
												ev.flags |= 1 << GuitarNoteFlags.Harm;
												break;
											case 6:
												ev.flags |= 1 << GuitarNoteFlags.ArtificialHarm;
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
								ev.position = MIDINote.C4 + note;
								goto current_difficulty;

							case MIDINote.C4: .. case MIDINote.C6:
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
}

// HACK: workaround since we can't initialise static AA's
__gshared immutable Streams[string] musicFileNames;
shared static this()
{
	musicFileNames =
	[
		"song":			Streams.Song,
		"song+crowd":	Streams.Vocals,
		"vocals":		Streams.Vocals,
		"crowd":		Streams.Crowd,
		"guitar":		Streams.Guitar,
		"rhythm":		Streams.Rhythm,
		"drums":		Streams.Drums,
		"drums_1":		Streams.Kick,
		"drums_2":		Streams.Snare,
		"drums_3":		Streams.Cymbals,
		"drums_4":		Streams.Toms
	];
}
