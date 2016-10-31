module db.formats.sm;

import fuji.fuji;
import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import db.chart;
import db.instrument;
import db.instrument.dance : DanceNotes, DanceFlags;
import db.tools.filetypes;
import db.library;

import std.algorithm;
import std.string;
import std.path;
import std.exception;
import std.conv : to;

bool LoadSM(Song* song, DirEntry file)
{
	string steps = enforce(MFFileSystem_LoadText(file.filepath).assumeUnique, "");

	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

	song._chart = new Chart;

	string name = file.filename.stripExtension;
	song._chart.params["original_name"] = name;
	song._chart.name = name;

	// search for the music and other stuff...
	string songName = file.filename.stripExtension.toLower;
	foreach (f; dirEntries(path ~ "*", SpanMode.shallow))
	{
		string filename = f.filename.toLower;
		string fn = filename.stripExtension;
		if (isImageFile(filename))
		{
			if (fn[] == songName || fn[] == "disc")
				song.coverImage = f.filepath;
			else if (fn[] == songName ~ "-bg" || fn[] == "back" || fn[] == "title" || fn[] == "title-bg")
				song.background = f.filepath;
		}
		else if (isAudioFile(filename))
		{
			if (fn[] == songName || fn[] == "song")
				song.addSource().addStream(f.filepath);
			if (fn[] == "intro")
				song._preview = f.filepath;
		}
		else if (isVideoFile(filename))
		{
			if (fn[] == songName || fn[] == "song")
				song.video = f.filepath;
		}
		else if (filename[] == songName ~ ".lrc")
		{
			// load lyrics into vocal track?
			// move this into the DWI loader?
		}
	}

	// load the steps
	song.LoadSM(steps, path);

	return true;
}

bool LoadSM(Song* song, const(char)[] sm, string path)
{
	Chart chart = song._chart;
	chart.params["source_format"] = ".sm";

	// Format description:
	// http://www.stepmania.com/wiki/The_.SM_file_format

	enum SMResolution = 48;
	chart.resolution = SMResolution;

	while (1)
	{
		auto start = sm.find('#');
		if (!start)
			break;
		size_t split = start.countUntil(':');
		if (split == -1)
			break;

		// get the tag
		auto tag = start[1..split];

		auto end = countUntil(start[split..$], ";");
		if (end == -1)
			break;

		// get the content
		auto content = start[split+1..split+end];
		sm = start[split+end+1..$];

		if (!content.length)
			continue;

		switch (tag)
		{
			case "TITLE":
				chart.name = content.idup;
				chart.params[tag.idup] = song.name;
				break;
			case "SUBTITLE":
				chart.subtitle = content.idup;
				chart.params[tag.idup] = song.subtitle;
				break;
			case "ARTIST":
				chart.artist = content.idup;
				chart.params[tag.idup] = song.artist;
				break;
			case "TITLETRANSLIT":
				chart.params[tag.idup] = content.idup;
				break;
			case "SUBTITLETRANSLIT":
				chart.params[tag.idup] = content.idup;
				break;
			case "ARTISTTRANSLIT":
				chart.params[tag.idup] = content.idup;
				break;
			case "GENRE":
				chart.genre = content.idup;
				chart.packageName = song.genre;
				chart.params[tag.idup] = song.genre;
				break;
			case "CREDIT":
				chart.params[tag.idup] = content.idup;
				chart.charterName = content.idup;
				break;
			case "BANNER":
				chart.params[tag.idup] = content.idup;
				song.coverImage = (path ~ content).idup;
				break;
			case "BACKGROUND":
				chart.params[tag.idup] = content.idup;
				song.background = (path ~ content).idup;
				break;
			case "LYRICSPATH":
				chart.params[tag.idup] = content.idup;
				break;
			case "CDTITLE":
				chart.params[tag.idup] = content.idup;
				break;
			case "MUSIC":
				chart.params[tag.idup] = content.idup;
				song.addSource().addStream((path ~ content).idup);
				break;
			case "OFFSET":
				chart.params[tag.idup] = content.idup;
				chart.startOffset = cast(long)(to!double(content)*1_000_000);
				break;
			case "SAMPLESTART":
				chart.params[tag.idup] = content.idup;
				break;
			case "SAMPLELENGTH":
				chart.params[tag.idup] = content.idup;
				break;
			case "SELECTABLE":
				chart.params[tag.idup] = content.idup;
				break;
			case "BPMS":
				chart.params[tag.idup] = content.idup;

				Event ev;
				ev.tick = 0;

				// we need to write a time signature first...
				ev.event = EventType.TimeSignature;
				ev.ts.numerator = 4;
				ev.ts.denominator = 4;
				chart.sync ~= ev;

				auto bpms = content.splitter(',');
				foreach (b; bpms)
				{
					auto params = b.findSplit("=");
					double offset = to!double(params[0]);
					double bpm = to!double(params[2]);

					ev.tick = cast(int)(offset*cast(double)SMResolution);
					ev.event = EventType.BPM;
					ev.bpm.usPerBeat = cast(int)(60_000_000.0 / bpm + 0.5);
					chart.sync ~= ev;
				}
				break;
			case "DISPLAYBPM":
				// a    - BPM stays set at 'a' value (no cycling)
				// a:b  - BPM cycles between 'a' and 'b' values
				// *    - BPM cycles randomly
				chart.params[tag.idup] = content.idup;
				break;
			case "STOPS":
				chart.params[tag.idup] = content.idup;

				auto freezes = content.splitter(',');
				foreach (f; freezes)
				{
					auto params = f.findSplit("=");
					double offset = to!double(params[0]);
					double seconds = to!double(params[2]);

					Event ev;
					ev.tick = cast(int)(offset*SMResolution);
					ev.event = EventType.Freeze;
					ev.freeze.usToFreeze = cast(long)(seconds*1_000_1000);
					chart.sync ~= ev;
				}
				break;
			case "BGCHANGE":
				chart.params[tag.idup] = content.idup;
				break;
			case "FGCHANGE":
				chart.params[tag.idup] = content.idup;
				break;
			case "MENUCOLOR":
				chart.params[tag.idup] = content.idup;
				break;
			case "NOTES":
				auto parts = content.splitter(':');
				auto type = parts.front.strip; parts.popFront;
				auto desc = parts.front.strip; parts.popFront;
				auto difficulty = parts.front.strip; parts.popFront;
				auto meter = parts.front.strip; parts.popFront;
				auto radar = parts.front.strip; parts.popFront;

				Track trk = new Track;
				trk.part = "dance";
				trk.variation = type.idup;
				trk.difficulty = difficulty.idup;
				trk.difficultyMeter = to!int(meter);

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

					switch (type)
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
				foreach (m; measures)
				{
					auto lines = m.strip.splitLines;
					if (lines[0].length < map.length || lines[0][0..2] == "//")
						lines = lines[1..$];

					int step = SMResolution*4 / cast(int)lines.length;

					foreach (int i, line; lines)
					{
						foreach (n, note; line.strip[0..map.length])
						{
							if (note == '3')
							{
								// set the duration for the last freeze arrow
								trk.notes[holds[n]].duration = offset + i*step - trk.notes[holds[n]].tick;
								holds[n] = -1;
							}
							else if (note != '0')
							{
								Event ev;
								ev.tick = offset + i*step;
								ev.event = EventType.Note;
								ev.note.key = map[n];

								if (note != '1')
								{
									if (note == '2' || note == '4')
										holds[n] = trk.notes.length;

									if (note == '4')
										ev.flags |= MFBit!(DanceFlags.Roll);
									else if (note == 'M')
										ev.flags |= MFBit!(DanceFlags.Mine);
									else if (note == 'L')
										ev.flags |= MFBit!(DanceFlags.Lift);
									else if (note == 'F')
										ev.flags |= MFBit!(DanceFlags.Fake);
									else if (note == 'S')
										ev.flags |= MFBit!(DanceFlags.Shock);
									else if (note >= 'a' && note <= 'z')
									{
										ev.flags |= MFBit!(DanceFlags.Sound);
										ev.flags |= (note - 'a') << 24;
									}
									else if (note >= 'A' && note <= 'Z')
									{
										ev.flags |= MFBit!(DanceFlags.Sound);
										ev.flags |= (note - 'A' + 26) << 24;
									}
								}

								trk.notes ~= ev;
							}
						}
					}

					offset += SMResolution*4;
				}

				// find variation for tag, if there isn't one, create it.
				Variation* pVariation = chart.getVariation(chart.getPart("dance"), type, true);

				// create difficulty, set difficulty to feet rating
				assert(!chart.GetDifficulty(*pVariation, difficulty), "Difficulty already exists!");
				pVariation.difficulties ~= trk;
				break;

			default:
				MFDebug_Warn(2, "Unknown tag: " ~ tag);
				break;
		}
	}

	// since freezes and bpm changes are added at different times, they need to be sorted
	chart.sync.sort!("a.tick < b.tick");

	// split subtitle into variation
	if (song._chart.name[$-1] == ')')
	{
		ptrdiff_t i;
		for (i=song._chart.name.length-2; i>0; --i)
		{
			if (song._chart.name[i] == '(')
			{
				song._chart.variant = song._chart.name[i+1..$-1].strip;
				song._chart.subtitle = song._chart.variant;
				song._chart.name = song._chart.name[0..i].strip;
				break;
			}
		}
	}

	return false;
}
