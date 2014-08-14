module db.formats.dwi;

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
import std.encoding;
import std.range: back, empty;
import std.path;
import std.exception;

bool LoadDWI(Track* track, DirEntry file)
{
	string steps = enforce(MFFileSystem_LoadText(file.filepath).assumeUnique, "");

	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

	track.song = new Song;
	track.song.params["source_format"] = ".dwi";

	string name = file.filename.stripExtension;
	track.song.params["original_name"] = name;
	track.song.name = name;

	// search for the music and other stuff...
	string songName = name.toLower;
	foreach(f; dirEntries(path ~ "*", SpanMode.shallow))
	{
		string filename = f.filename.toLower;
		string fn = filename.stripExtension;
		if(isImageFile(filename))
		{
			if(fn[] == songName || fn[] == "disc")
				track.cover = f.filepath;
			else if(fn[] == songName ~ "-bg" || fn[] == "back" || fn[] == "title" || fn[] == "title-bg")
				track.background = f.filepath;
		}
		else if(isAudioFile(filename))
		{
			if(fn[] == songName || fn[] == "song")
				track.addSource().addStream(f.filepath);
			if(fn[] == "intro")
				track.preview = f.filepath;
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
	track.LoadDWI(steps, path);

	// split subtitle into variation
	if(track.song.name[$-1] == ')')
	{
		ptrdiff_t i;
		for(i=track.song.name.length-2; i>0; --i)
		{
			if(track.song.name[i] == '(')
			{
				track.song.variant = track.song.name[i+1..$-1].strip;
				track.song.subtitle = track.song.variant;
				track.song.name = track.song.name[0..i].strip;
				break;
			}
		}
	}

	return true;
}

bool LoadDWI(Track* track, const(char)[] dwi, string path)
{
	Song song = track.song;

	// Format description:
	// http://dwi.ddruk.com/readme.php#4

	enum DwiResolution = 48;
	song.resolution = DwiResolution;

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
				song.name = content.idup;
				song.params[tag.idup] = song.name;
				break;
			case "ARTIST":			// #ARTIST:...;  	 artist of the song.
				song.artist = content.idup;
				song.params[tag.idup] = song.artist;
				break;

				// Special Characters are denoted by giving filenames in curly-brackets.
				//   eg. #DISPLAYTITLE:The {kanji.png} Song;
				// The extra character files should be 50 pixels high and be black-and-white. The baseline for the font should be 34 pixels from the top.
			case "DISPLAYTITLE":	// #DISPLAYTITLE:...;  	 provides an alternate version of the song name that can also include special characters.
				song.params[tag.idup] = content.idup;
				break;
			case "DISPLAYARTIST":	// #DISPLAYARTIST:...; 	 provides an alternate version of the artist name that can also include special characters.
				song.params[tag.idup] = content.idup;
				break;

			case "GAP":				// #GAP:...;  	 number of milliseconds that pass before the program starts counting beats. Used to sync the steps to the music.
				song.params[tag.idup] = content.idup;
				song.startOffset = to!long(content)*1_000;
				break;
			case "BPM":				// #BPM:...;  	 BPM of the music
				song.params[tag.idup] = content.idup;

				Event ev;
				ev.tick = 0;

				// we need to write a time signature first...
				ev.event = EventType.TimeSignature;
				ev.ts.numerator = 4;
				ev.ts.denominator = 4;
				song.sync ~= ev;

				// set the starting BPM
				ev.event = EventType.BPM;
				ev.bpm.usPerBeat = cast(int)(60_000_000.0 / to!double(content) + 0.5);
				song.sync ~= ev;
				break;
			case "DISPLAYBPM":		// #DISPLAYBPM:...;	tells DWI to display the BPM on the song select screen in a user-defined way.  Options can be:
				// *    - BPM cycles randomly
				// a    - BPM stays set at 'a' value (no cycling)
				// a..b - BPM cycles between 'a' and 'b' values
				song.params[tag.idup] = content.idup;
				break;
			case "FILE":			// #FILE:...;  	 path to the music file to play (eg. /music/mysongs/abc.mp3 )
				// TODO: check if it exists?
				track.addSource().addStream((path ~ content).idup);
				song.params[tag.idup] = content.idup;
				break;
			case "MD5":				// #MD5:...;  	 an MD5 string for the music file. Helps ensure that same music file is used on all systems.
				song.params[tag.idup] = content.idup;
				break;
			case "FREEZE":			// #FREEZE:...;  	 a value of the format "BBB=sss". Indicates that at 'beat' "BBB", the motion of the arrows should stop for "sss" milliseconds. Turn on beat-display in the System menu to help determine what values to use. Multiple freezes can be given by separating them with commas.
				song.params[tag.idup] = content.idup;

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
					song.sync ~= ev;
				}
				break;
			case "CHANGEBPM":		// #CHANGEBPM:...;  	 a value of the format "BBB=nnn". Indicates that at 'beat' "BBB", the speed of the arrows will change to reflect a new BPM of "nnn". Multiple BPM changes can be given by separating them with commas.
				song.params[tag.idup] = content.idup;

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
					song.sync ~= ev;
				}
				break;
			case "STATUS":			// #STATUS:...;  	 can be "NEW" or "NORMAL". Changes the display of songs on the song-select screen.
				song.params[tag.idup] = content.idup;
				break;
			case "GENRE":			// #GENRE:...;  	 a genre to assign to the song if "sort by Genre" is selected in the System Options. Multiple Genres can be given by separating them with commas.
				song.genre = content.idup;
				song.packageName = song.genre;
				song.params[tag.idup] = song.genre;
				break;
			case "CDTITLE":			// #CDTITLE:...;  	 points to a small graphic file (64x40) that will display in the song selection screen in the bottom right of the background, showing which CD the song is from. The colour of the pixel in the upper-left will be made transparent.
				song.params[tag.idup] = content.idup;
				break;
			case "SAMPLESTART":		// #SAMPLESTART:...;  	 the time in the music file that the preview music should start at the song-select screen. Can be given in Milliseconds (eg. 5230), Seconds (eg. 5.23), or minutes (eg. 0:05.23). Prefix the number with a "+" to factor in the GAP value.
				song.params[tag.idup] = content.idup;
				break;
			case "SAMPLELENGTH":	// #SAMPLELENGTH:...;  	 how long to play the preview music for at the song-select screen. Can be in milliseconds, seconds, or minutes.
				song.params[tag.idup] = content.idup;
				break;
			case "RANDSEED":		// #RANDSEED:x;  	 provide a number that will influence what AVIs DWI picks and their order. Will be the same animation each time if AVI filenames and count doesn't change (default is random each time).
				song.params[tag.idup] = content.idup;
				break;
			case "RANDSTART":		// #RANDSTART:x;  	 tells DWI what beat to start the animations on. Default is 32.
				song.params[tag.idup] = content.idup;
				break;
			case "RANDFOLDER":		// #RANDFOLDER:...;  	 tells DWI to look in another folder when choosing AVIs, allowing 'themed' folders.
				song.params[tag.idup] = content.idup;
				break;
			case "RANDLIST":		// #RANDLIST:...;  	 a list of comma-separated filenames to use in the folder.
				song.params[tag.idup] = content.idup;
				break;
			case "BACKGROUND":		// #BACKGROUND:     ........     #END;
				song.params[tag.idup] = content.idup;
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
					Variation* pVariation = song.GetVariation(Part.Dance, seq.variation, true);

					// create difficulty, set difficulty to feet rating
					assert(!song.GetDifficulty(*pVariation, seq.difficulty), "Difficulty already exists!");
					pVariation.difficulties ~= seq;
				}
				break;

			default:
				MFDebug_Warn(2, "Unknown tag: " ~ tag);
				break;
		}
	}

	// since freezes and bpm changes are added at different times, they need to be sorted
	song.sync.sort!("a.tick < b.tick");

	return false;
}
