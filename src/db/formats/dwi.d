module db.formats.dwi;

import fuji.fuji;
import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import db.chart;
import db.instrument;
import db.tools.filetypes;
import db.library;
import db.instrument.dance : DanceNotes;

import std.algorithm;
import std.string;
import std.encoding;
import std.range: back, empty;
import std.path;
import std.exception;
import std.conv : to;

bool LoadDWI(Song* song, DirEntry file)
{
	string steps = enforce(MFFileSystem_LoadText(file.filepath).assumeUnique, "");

	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

	song._chart = new Chart;
	song._chart.params["source_format"] = ".dwi";

	string name = file.filename.stripExtension;
	song._chart.params["original_name"] = name;
	song._chart.name = name;

	// search for the music and other stuff...
	string songName = name.toLower;
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
			// load lyrics into vocal song?
			// move this into the DWI loader?
		}
	}

	// load the steps
	song.LoadDWI(steps, path);

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

	return true;
}

bool LoadDWI(Song* song, const(char)[] dwi, string path)
{
	Chart chart = song._chart;

	// Format description:
	// http://dwi.ddruk.com/readme.php#4

	enum DwiResolution = 48;
	chart.resolution = DwiResolution;

	while (1)
	{
		auto start = dwi.find('#');
		if (!start)
			break;
		size_t split = start.countUntil(':');
		if (split == -1)
			break;

		// get the tag
		auto tag = start[1..split];

		string term = tag[] == "BACKGROUND" ? "#END;" : ";";
		auto end = countUntil(start[split..$], term);
		if (end == -1)
			break;

		// get the content
		auto content = start[split+1..split+end];
		dwi = start[split+end+term.length..$];

		switch (tag)
		{
			case "TITLE":			// #TITLE:...;  	 title of the song.
				chart.name = content.idup;
				chart.params[tag.idup] = song.name;
				break;
			case "ARTIST":			// #ARTIST:...;  	 artist of the song.
				chart.artist = content.idup;
				chart.params[tag.idup] = song.artist;
				break;

				// Special Characters are denoted by giving filenames in curly-brackets.
				//   eg. #DISPLAYTITLE:The {kanji.png} Song;
				// The extra character files should be 50 pixels high and be black-and-white. The baseline for the font should be 34 pixels from the top.
			case "DISPLAYTITLE":	// #DISPLAYTITLE:...;  	 provides an alternate version of the song name that can also include special characters.
				chart.params[tag.idup] = content.idup;
				break;
			case "DISPLAYARTIST":	// #DISPLAYARTIST:...; 	 provides an alternate version of the artist name that can also include special characters.
				chart.params[tag.idup] = content.idup;
				break;

			case "GAP":				// #GAP:...;  	 number of milliseconds that pass before the program starts counting beats. Used to sync the steps to the music.
				chart.params[tag.idup] = content.idup;
				chart.startOffset = to!long(content)*1_000;
				break;
			case "BPM":				// #BPM:...;  	 BPM of the music
				chart.params[tag.idup] = content.idup;

				Event ev;
				ev.tick = 0;

				// we need to write a time signature first...
				ev.event = EventType.TimeSignature;
				ev.ts.numerator = 4;
				ev.ts.denominator = 4;
				chart.sync ~= ev;

				// set the starting BPM
				ev.event = EventType.BPM;
				ev.bpm.usPerBeat = cast(int)(60_000_000.0 / to!double(content) + 0.5);
				chart.sync ~= ev;
				break;
			case "DISPLAYBPM":		// #DISPLAYBPM:...;	tells DWI to display the BPM on the song select screen in a user-defined way.  Options can be:
				// *    - BPM cycles randomly
				// a    - BPM stays set at 'a' value (no cycling)
				// a..b - BPM cycles between 'a' and 'b' values
				chart.params[tag.idup] = content.idup;
				break;
			case "FILE":			// #FILE:...;  	 path to the music file to play (eg. /music/mysongs/abc.mp3 )
				// TODO: check if it exists?
				song.addSource().addStream((path ~ content).idup);
				chart.params[tag.idup] = content.idup;
				break;
			case "MD5":				// #MD5:...;  	 an MD5 string for the music file. Helps ensure that same music file is used on all systems.
				chart.params[tag.idup] = content.idup;
				break;
			case "FREEZE":			// #FREEZE:...;  	 a value of the format "BBB=sss". Indicates that at 'beat' "BBB", the motion of the arrows should stop for "sss" milliseconds. Turn on beat-display in the System menu to help determine what values to use. Multiple freezes can be given by separating them with commas.
				chart.params[tag.idup] = content.idup;

				auto freezes = content.splitter(',');
				foreach (f; freezes)
				{
					auto params = f.findSplit("=");
					double offset = to!double(params[0]);
					double ms = to!double(params[2]);

					Event ev;
					ev.tick = cast(int)(offset*DwiResolution) / 4; // TODO: wtf? why /4?? It's supposed to be in beats!
					ev.event = EventType.Freeze;
					ev.freeze.usToFreeze = cast(long)(ms*1_000);
					chart.sync ~= ev;
				}
				break;
			case "CHANGEBPM":		// #CHANGEBPM:...;  	 a value of the format "BBB=nnn". Indicates that at 'beat' "BBB", the speed of the arrows will change to reflect a new BPM of "nnn". Multiple BPM changes can be given by separating them with commas.
				chart.params[tag.idup] = content.idup;

				auto bpms = content.splitter(',');
				foreach (b; bpms)
				{
					auto params = b.findSplit("=");
					double offset = to!double(params[0]);
					double bpm = to!double(params[2]);

					Event ev;
					ev.tick = cast(int)(offset*cast(double)DwiResolution) / 4; // TODO: wtf? why /4?? It's supposed to be in beats!
					ev.event = EventType.BPM;
					ev.bpm.usPerBeat = cast(int)(60_000_000.0 / bpm + 0.5);
					chart.sync ~= ev;
				}
				break;
			case "STATUS":			// #STATUS:...;  	 can be "NEW" or "NORMAL". Changes the display of songs on the song-select screen.
				chart.params[tag.idup] = content.idup;
				break;
			case "GENRE":			// #GENRE:...;  	 a genre to assign to the song if "sort by Genre" is selected in the System Options. Multiple Genres can be given by separating them with commas.
				chart.genre = content.idup;
				chart.packageName = song.genre;
				chart.params[tag.idup] = song.genre;
				break;
			case "CDTITLE":			// #CDTITLE:...;  	 points to a small graphic file (64x40) that will display in the song selection screen in the bottom right of the background, showing which CD the song is from. The colour of the pixel in the upper-left will be made transparent.
				chart.params[tag.idup] = content.idup;
				break;
			case "SAMPLESTART":		// #SAMPLESTART:...;  	 the time in the music file that the preview music should start at the song-select screen. Can be given in Milliseconds (eg. 5230), Seconds (eg. 5.23), or minutes (eg. 0:05.23). Prefix the number with a "+" to factor in the GAP value.
				chart.params[tag.idup] = content.idup;
				break;
			case "SAMPLELENGTH":	// #SAMPLELENGTH:...;  	 how long to play the preview music for at the song-select screen. Can be in milliseconds, seconds, or minutes.
				chart.params[tag.idup] = content.idup;
				break;
			case "RANDSEED":		// #RANDSEED:x;  	 provide a number that will influence what AVIs DWI picks and their order. Will be the same animation each time if AVI filenames and count doesn't change (default is random each time).
				chart.params[tag.idup] = content.idup;
				break;
			case "RANDSTART":		// #RANDSTART:x;  	 tells DWI what beat to start the animations on. Default is 32.
				chart.params[tag.idup] = content.idup;
				break;
			case "RANDFOLDER":		// #RANDFOLDER:...;  	 tells DWI to look in another folder when choosing AVIs, allowing 'themed' folders.
				chart.params[tag.idup] = content.idup;
				break;
			case "RANDLIST":		// #RANDLIST:...;  	 a list of comma-separated filenames to use in the folder.
				chart.params[tag.idup] = content.idup;
				break;
			case "BACKGROUND":		// #BACKGROUND:     ........     #END;
				chart.params[tag.idup] = content.idup;
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

					enum string[string] typeMap = [ "SINGLE":"dance-single", "DOUBLE":"dance-double", "COUPLE":"dance-couple", "SOLO":"dance-solo" ];
					enum Difficulty[string] difficultyMap = [ "BEGINNER": Difficulty.Beginner, "BASIC": Difficulty.Easy, "ANOTHER": Difficulty.Medium, "MANIAC": Difficulty.Hard, "SMANIAC": Difficulty.Expert ];

					auto parts = content.splitter(':');
					auto diff = parts.front.strip; parts.popFront;
					auto meter = parts.front.strip; parts.popFront;
					auto left = parts.front.strip; parts.popFront;
					auto right = parts.empty ? null : parts.front.strip;

					string type = tag in typeMap ? typeMap[tag] : tag.idup;

					Track trk = new Track;
					trk.part = "dance";
					trk.variationType = type;
					trk.difficultyMeter = to!int(meter);

					Difficulty* pDiff = diff in difficultyMap;
					if (pDiff)
					{
						trk.difficulty = *pDiff;
						trk.difficultyName = diff.idup;
					}
					else
					{
						trk.variationName = diff.idup;
						trk.difficulty = Difficulty.Expert; // TODO: change this to some non-ordered difficulty?
						trk.difficultyName = "EDIT";
					}

					// read notes...
					static void ReadNotes(Track trk, const(char)[] steps, int shift)
					{
						int offset;

						int[16] step;
						int depth;
						step[depth] = 8;

						bool bHold;

						ptrdiff_t[9] holds = -1;

						foreach (s; steps)
						{
							switch (s)
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
									if (bHold)
									{
										// set the notes as holds
										auto pNote = s in stepMap;
										uint note = pNote ? *pNote : 0;

										int lastOffset = trk.notes.back.tick;
										if (note)
										{
											for (int i=0; i<9; ++i)
											{
												if (note & 1<<i)
												{
													for (size_t j=trk.notes.length-1; j>=0 && trk.notes[j].tick == lastOffset; --j)
													{
														if (trk.notes[j].note.key == i+shift)
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
										if (note)
										{
											// produce a note for each bit
											for (int i=0; i<9; ++i)
											{
												if (note & 1<<i)
												{
													if (holds[i] != -1)
													{
														// terminate the hold
														Event* pNote = &trk.notes[holds[i]];
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
														trk.notes ~= ev;
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

					ReadNotes(trk, left, 0);
					if (!right.empty)
					{
						ReadNotes(trk, right, DanceNotes.Left2);
						trk.notes.sort!("a.tick < b.tick", SwapStrategy.stable);
					}

					// find variation, if there isn't one, create it.
					Variation* pVariation = chart.getVariation(chart.getPart("dance"), trk.variationType, trk.variationName, true);

					// create difficulty, set difficulty to feet rating
					assert(!chart.getDifficulty(*pVariation, trk.difficulty), "Difficulty already exists!");
					pVariation.difficulties ~= trk;
				}
				break;

			default:
				MFDebug_Warn(2, "Unknown tag: " ~ tag);
				break;
		}
	}

	// since freezes and bpm changes are added at different times, they need to be sorted
	chart.sync.sort!("a.tick < b.tick");

	return false;
}
