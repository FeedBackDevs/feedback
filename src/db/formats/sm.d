module db.formats.sm;

import fuji.fuji;
import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import db.song;
import db.sequence;
import db.instrument;
import db.tools.filetypes;

import std.algorithm;
import std.string;
import std.path;
import std.exception;

Song LoadSM(DirEntry file)
{
	const(char)[] steps = cast(const(char)[])enforce(MFFileSystem_Load(file.filepath), "");
	scope(exit) MFHeap_Free(cast(void[])steps);

	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

	Song song = new Song;
	song.songPath = path;
	song.id = file.filename.stripExtension;
	song.name = song.id;

	// search for the music and other stuff...
	string songName = file.filename.stripExtension.toLower;
	foreach(f; dirEntries(path ~ "*", SpanMode.shallow))
	{
		string filename = f.filename.toLower;
		string fn = filename.stripExtension;
		if(isImageFile(filename))
		{
			if(fn[] == songName || fn[] == "disc")
				song.cover = f.filename;
			else if(fn[] == songName ~ "-bg" || fn[] == "back" || fn[] == "title" || fn[] == "title-bg")
				song.background = f.filename;
		}
		else if(isAudioFile(filename))
		{
			if(fn[] == songName || fn[] == "song")
				song.musicFiles[MusicFiles.Song] = f.filename;
			if(fn[] == "intro")
				song.musicFiles[MusicFiles.Preview] = f.filename;
		}
		else if(isVideoFile(filename))
		{
			if(fn[] == songName || fn[] == "song")
				song.video = f.filename;
		}
		else if(filename[] == songName ~ ".lrc")
		{
			// load lyrics into vocal track?
			// move this into the DWI loader?
		}
	}

	// load the steps
	song.LoadSM(steps);

	return song;
}

bool LoadSM(Song song, const(char)[] sm)
{
	with(song)
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
}
