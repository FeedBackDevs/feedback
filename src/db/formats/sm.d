module db.formats.sm;

import fuji.fuji;
import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import db.song;
import db.sequence;
import db.instrument;
import db.tools.filetypes;
import db.songlibrary;

import std.algorithm;
import std.string;
import std.path;
import std.exception;
import std.conv : to;

bool LoadSM(Track* track, DirEntry file)
{
	string steps = enforce(MFFileSystem_LoadText(file.filepath).assumeUnique, "");

	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

	track._song = new Song;

	string name = file.filename.stripExtension;
	track._song.params["original_name"] = name;
	track._song.name = name;

	// search for the music and other stuff...
	string songName = file.filename.stripExtension.toLower;
	foreach(f; dirEntries(path ~ "*", SpanMode.shallow))
	{
		string filename = f.filename.toLower;
		string fn = filename.stripExtension;
		if(isImageFile(filename))
		{
			if(fn[] == songName || fn[] == "disc")
				track.coverImage = f.filepath;
			else if(fn[] == songName ~ "-bg" || fn[] == "back" || fn[] == "title" || fn[] == "title-bg")
				track.background = f.filepath;
		}
		else if(isAudioFile(filename))
		{
			if(fn[] == songName || fn[] == "song")
				track.addSource().addStream(f.filepath);
			if(fn[] == "intro")
				track._preview = f.filepath;
		}
		else if(isVideoFile(filename))
		{
			if(fn[] == songName || fn[] == "song")
				track.video = f.filepath;
		}
		else if(filename[] == songName ~ ".lrc")
		{
			// load lyrics into vocal track?
			// move this into the DWI loader?
		}
	}

	// load the steps
	track.LoadSM(steps, path);

	return true;
}

bool LoadSM(Track* track, const(char)[] sm, string path)
{
	Song song = track._song;
	song.params["source_format"] = ".sm";

	// Format description:
	// http://www.stepmania.com/wiki/The_.SM_file_format

	enum SMResolution = 48;
	song.resolution = SMResolution;

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
				song.name = content.idup;
				song.params[tag.idup] = song.name;
				break;
			case "SUBTITLE":
				song.subtitle = content.idup;
				song.params[tag.idup] = song.subtitle;
				break;
			case "ARTIST":
				song.artist = content.idup;
				song.params[tag.idup] = song.artist;
				break;
			case "TITLETRANSLIT":
				song.params[tag.idup] = content.idup;
				break;
			case "SUBTITLETRANSLIT":
				song.params[tag.idup] = content.idup;
				break;
			case "ARTISTTRANSLIT":
				song.params[tag.idup] = content.idup;
				break;
			case "GENRE":
				song.genre = content.idup;
				song.packageName = song.genre;
				song.params[tag.idup] = song.genre;
				break;
			case "CREDIT":
				song.params[tag.idup] = content.idup;
				song.charterName = content.idup;
				break;
			case "BANNER":
				song.params[tag.idup] = content.idup;
				track.coverImage = (path ~ content).idup;
				break;
			case "BACKGROUND":
				song.params[tag.idup] = content.idup;
				track.background = (path ~ content).idup;
				break;
			case "LYRICSPATH":
				song.params[tag.idup] = content.idup;
				break;
			case "CDTITLE":
				song.params[tag.idup] = content.idup;
				break;
			case "MUSIC":
				song.params[tag.idup] = content.idup;
				track.addSource().addStream((path ~ content).idup);
				break;
			case "OFFSET":
				song.params[tag.idup] = content.idup;
				song.startOffset = cast(long)(to!double(content)*1_000_000);
				break;
			case "SAMPLESTART":
				song.params[tag.idup] = content.idup;
				break;
			case "SAMPLELENGTH":
				song.params[tag.idup] = content.idup;
				break;
			case "SELECTABLE":
				song.params[tag.idup] = content.idup;
				break;
			case "BPMS":
				song.params[tag.idup] = content.idup;

				Event ev;
				ev.tick = 0;

				// we need to write a time signature first...
				ev.event = EventType.TimeSignature;
				ev.ts.numerator = 4;
				ev.ts.denominator = 4;
				song.sync ~= ev;

				auto bpms = content.splitter(',');
				foreach(b; bpms)
				{
					auto params = b.findSplit("=");
					double offset = to!double(params[0]);
					double bpm = to!double(params[2]);

					ev.tick = cast(int)(offset*cast(double)SMResolution);
					ev.event = EventType.BPM;
					ev.bpm.usPerBeat = cast(int)(60_000_000.0 / bpm + 0.5);
					song.sync ~= ev;
				}
				break;
			case "DISPLAYBPM":
				// a    - BPM stays set at 'a' value (no cycling)
				// a:b  - BPM cycles between 'a' and 'b' values
				// *    - BPM cycles randomly
				song.params[tag.idup] = content.idup;
				break;
			case "STOPS":
				song.params[tag.idup] = content.idup;

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
					song.sync ~= ev;
				}
				break;
			case "BGCHANGE":
				song.params[tag.idup] = content.idup;
				break;
			case "FGCHANGE":
				song.params[tag.idup] = content.idup;
				break;
			case "MENUCOLOR":
				song.params[tag.idup] = content.idup;
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
										ev.flags |= MFBit!(DanceFlags.Roll);
									else if(note == 'M')
										ev.flags |= MFBit!(DanceFlags.Mine);
									else if(note == 'L')
										ev.flags |= MFBit!(DanceFlags.Lift);
									else if(note == 'F')
										ev.flags |= MFBit!(DanceFlags.Fake);
									else if(note == 'S')
										ev.flags |= MFBit!(DanceFlags.Shock);
									else if(note >= 'a' && note <= 'z')
									{
										ev.flags |= MFBit!(DanceFlags.Sound);
										ev.flags |= (note - 'a') << 24;
									}
									else if(note >= 'A' && note <= 'Z')
									{
										ev.flags |= MFBit!(DanceFlags.Sound);
										ev.flags |= (note - 'A' + 26) << 24;
									}
								}

								seq.notes ~= ev;
							}
						}
					}

					offset += SMResolution*4;
				}

				// find variation for tag, if there isn't one, create it.
				Variation* pVariation = song.GetVariation(Part.Dance, type, true);

				// create difficulty, set difficulty to feet rating
				assert(!song.GetDifficulty(*pVariation, difficulty), "Difficulty already exists!");
				pVariation.difficulties ~= seq;
				break;

			default:
				MFDebug_Warn(2, "Unknown tag: " ~ tag);
				break;
		}
	}

	// since freezes and bpm changes are added at different times, they need to be sorted
	song.sync.sort!("a.tick < b.tick");

	// split subtitle into variation
	if(track._song.name[$-1] == ')')
	{
		ptrdiff_t i;
		for(i=track._song.name.length-2; i>0; --i)
		{
			if(track._song.name[i] == '(')
			{
				track._song.variant = track._song.name[i+1..$-1].strip;
				track._song.subtitle = track._song.variant;
				track._song.name = track._song.name[0..i].strip;
				break;
			}
		}
	}

	return false;
}
