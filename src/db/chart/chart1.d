module db.chart.chart1;

import db.chart;
import db.library : archiveName;
import std.algorithm : startsWith, splitter, copy;
import std.conv : to;
import std.range : empty;
import std.string : strip, lineSplitter;

void parseChart1_0(Chart chart, string file)
{
	enum Section
	{
		Header,
		Sync,
		Events,
		Track
	}

	Section section;
	Part* pPart;
	Track trk;
	bool expectTag = true;
	bool expectOpenBrace = false;
	bool bassIsRhythm = false;

	chart.params["source_format"] = ".chart_1_0";

	foreach (line; file.lineSplitter) with (chart)
	{
		line = line.strip;
		if (line.empty)
			continue;

		if (expectOpenBrace)
		{
			if (line[] != "{")
				throw new Exception("Expected '{'");
			expectOpenBrace = false;
			continue;
		}

		if (line[0] == '[' && line[$-1] == ']')
		{
			if (!expectTag)
				throw new Exception("Header inside section!");
			expectTag = false;

			line = line[1 .. $-1];
			switch (line)
			{
				case "Song":				section = Section.Header;	trk = null;	break;
				case "SyncTrack":			section = Section.Sync;		trk = null;	break;
				case "Events":				section = Section.Events;	trk = null;	break;
				case "EasySingle":			trk = createTrack("leadguitar", null, null, Difficulty.Easy);									section = Section.Track;	break;
				case "EasyDoubleGuitar":	trk = createTrack("leadguitar", null, "Coop", Difficulty.Easy);									section = Section.Track;	break;
				case "EasyDoubleBass":		trk = createTrack(bassIsRhythm ? "rhythmguitar" : "bass", null, null, Difficulty.Easy);			section = Section.Track;	break;
				case "EasyEnhancedGuitar":	trk = createTrack("leadguitar", null, "Enhanced", Difficulty.Easy);								section = Section.Track;	break;
				case "EasyCoopLead":		trk = createTrack("leadguitar", null, "EnhancedCoop", Difficulty.Easy);							section = Section.Track;	break;
				case "EasyCoopBass":		trk = createTrack(bassIsRhythm ? "rhythmguitar" : "bass", null, "Enhanced", Difficulty.Easy);	section = Section.Track;	break;
				case "Easy10KeyGuitar":		trk = createTrack("10keyguitar", null, null, Difficulty.Easy);									section = Section.Track;	break;
				case "EasyDrums":			trk = createTrack("drums", "gh-drums", null, Difficulty.Easy);									section = Section.Track;	break;
				case "EasyDoubleDrums":		trk = null;																						section = Section.Track;	break;
				case "EasyVocals":			trk = createTrack("vocals", null, null, Difficulty.Easy);										section = Section.Track;	break;
				case "EasyKeyboard":		trk = createTrack("keyboard", null, null, Difficulty.Easy);										section = Section.Track;	break;
				case "MediumSingle":		trk = createTrack("leadguitar", null, null, Difficulty.Medium);									section = Section.Track;	break;
				case "MediumDoubleGuitar":	trk = createTrack("leadguitar", null, "Coop", Difficulty.Medium);								section = Section.Track;	break;
				case "MediumDoubleBass":	trk = createTrack(bassIsRhythm ? "rhythmguitar" : "bass", null, null, Difficulty.Medium);		section = Section.Track;	break;
				case "MediumEnhancedGuitar":trk = createTrack("leadguitar", null, "Enhanced", Difficulty.Medium);							section = Section.Track;	break;
				case "MediumCoopLead":		trk = createTrack("leadguitar", null, "EnhancedCoop", Difficulty.Medium);						section = Section.Track;	break;
				case "MediumCoopBass":		trk = createTrack(bassIsRhythm ? "rhythmguitar" : "bass", null, "Enhanced", Difficulty.Medium);	section = Section.Track;	break;
				case "Medium10KeyGuitar":	trk = createTrack("10keyguitar", null, null, Difficulty.Medium);								section = Section.Track;	break;
				case "MediumDrums":			trk = createTrack("drums", "gh-drums", null, Difficulty.Medium);									section = Section.Track;	break;
				case "MediumDoubleDrums":	trk = null;																						section = Section.Track;	break;
				case "MediumVocals":		trk = createTrack("vocals", null, null, Difficulty.Medium);										section = Section.Track;	break;
				case "MediumKeyboard":		trk = createTrack("keyboard", null, null, Difficulty.Medium);									section = Section.Track;	break;
				case "HardSingle":			trk = createTrack("leadguitar", null, null, Difficulty.Hard);									section = Section.Track;	break;
				case "HardDoubleGuitar":	trk = createTrack("leadguitar", null, "Coop", Difficulty.Hard);									section = Section.Track;	break;
				case "HardDoubleBass":		trk = createTrack(bassIsRhythm ? "rhythmguitar" : "bass", null, null, Difficulty.Hard);			section = Section.Track;	break;
				case "HardEnhancedGuitar":	trk = createTrack("leadguitar", null, "Enhanced", Difficulty.Hard);								section = Section.Track;	break;
				case "HardCoopLead":		trk = createTrack("leadguitar", null, "EnhancedCoop", Difficulty.Hard);							section = Section.Track;	break;
				case "HardCoopBass":		trk = createTrack(bassIsRhythm ? "rhythmguitar" : "bass", null, "Enhanced", Difficulty.Hard);	section = Section.Track;	break;
				case "Hard10KeyGuitar":		trk = createTrack("10keyguitar", null, null, Difficulty.Hard);									section = Section.Track;	break;
				case "HardDrums":			trk = createTrack("drums", "gh-drums", null, Difficulty.Hard);									section = Section.Track;	break;
				case "HardDoubleDrums":		trk = null;																						section = Section.Track;	break;
				case "HardVocals":			trk = createTrack("vocals", null, null, Difficulty.Hard);										section = Section.Track;	break;
				case "HardKeyboard":		trk = createTrack("keyboard", null, null, Difficulty.Hard);										section = Section.Track;	break;
				case "ExpertSingle":		trk = createTrack("leadguitar", null, null, Difficulty.Expert);									section = Section.Track;	break;
				case "ExpertDoubleGuitar":	trk = createTrack("leadguitar", null, "Coop", Difficulty.Expert);								section = Section.Track;	break;
				case "ExpertDoubleBass":	trk = createTrack(bassIsRhythm ? "rhythmguitar" : "bass", null, null, Difficulty.Expert);		section = Section.Track;	break;
				case "ExpertEnhancedGuitar":trk = createTrack("leadguitar", null, "Enhanced", Difficulty.Expert);							section = Section.Track;	break;
				case "ExpertCoopLead":		trk = createTrack("leadguitar", null, "EnhancedCoop", Difficulty.Expert);						section = Section.Track;	break;
				case "ExpertCoopBass":		trk = createTrack(bassIsRhythm ? "rhythmguitar" : "bass", null, "Enhanced", Difficulty.Expert);	section = Section.Track;	break;
				case "Expert10KeyGuitar":	trk = createTrack("10keyguitar", null, null, Difficulty.Expert);								section = Section.Track;	break;
				case "ExpertDrums":			trk = createTrack("drums", "gh-drums", null, Difficulty.Expert);									section = Section.Track;	break;
				case "ExpertDoubleDrums":	trk = null;																						section = Section.Track;	break;
				case "ExpertVocals":		trk = createTrack("vocals", null, null, Difficulty.Expert);										section = Section.Track;	break;
				case "ExpertKeyboard":		trk = createTrack("keyboard", null, null, Difficulty.Expert);									section = Section.Track;	break;
				default:
					trk = null;
					section = Section.Track;
					break;
			}

			if (trk)
				pPart = getPart(trk.part);

			expectOpenBrace = true;
		}
		else if (expectTag)
		{
			throw new Exception("Expected tag!");
		}
		else if (line[] == "{")
		{
			throw new Exception("Unexpected open brace in section body!");
		}
		else if (line[] == "}")
		{
			expectTag = true;
		}
		else
		{
			// parse around '='
			auto tokens = line.splitter('=');
			auto left = tokens.front.strip;
			tokens.popFront;
			auto right = tokens.front.strip;

			final switch (section)
			{
				case Section.Header:
					switch (left)
					{
						case "Name":			name = right[1..$-1].idup;									break;
						case "Artist":			artist = right[1..$-1].idup;								break;
						case "Charter":			charterName = right[1..$-1].idup;							break;
						case "Offset":			startOffset = cast(long)(right.to!double * 1_000_000.0);	break;
						case "Resolution":		resolution = right.to!int;									break;
						case "Player2":			bassIsRhythm = right[] == "rhythm";							break;
						case "Genre":			genre = right[1..$-1].idup;									break;
						case "MediaType":		mediaType = right[1..$-1].idup;								break;
						case "MusicStream":
						case "GuitarStream":
						case "BassStream":
						case "Fretboard":
						case "MusicURL":
						case "PreviewURL":
							params[left] = right[1..$-1].idup;
							break;
						case "Difficulty":
						case "PreviewStart":
						case "PreviewEnd":
							params[left] = right.idup;
							break;
						default:
							params[left] = right.idup;
							break;
					}
					break;
				case Section.Track:
					if (trk is null)
						continue;
					goto case Section.Sync;
				case Section.Sync:
				case Section.Events:
				{
					Event ev;
					ev.tick = left.to!int;

					string[4] words;
					right.splitter.copy(words[]);

					switch (words[0])
					{
						case "B":
							ev.event = EventType.BPM;
							ev.bpm.usPerBeat = cast(int)(60_000_000_000.0 / words[1].to!double + 0.5);
							break;
						case "TS":
							ev.event = EventType.TimeSignature;
							ev.ts.numerator = words[1].to!int;
							ev.ts.denominator = 4;
							break;
						case "E":
							ev.event = EventType.Event;
							ev.text = right[1..$].strip[1 .. $-1].idup;

							if (ev.text.startsWith("section "))
							{
								ev.event = EventType.Section;
								ev.text = ev.text[8 .. $].strip;
							}
							else if (ev.text.startsWith("lighting "))
							{
								ev.event = EventType.Lighting;
								ev.text = ev.text[9 .. $].strip;
								if (ev.text.length >= 2 && ev.text[0] == '(' && ev.text[$-1] == ')')
									ev.text = ev.text[1 .. $-1];
							}
							else if (ev.text.startsWith("do_directed_cut "))
							{
								ev.event = EventType.DirectedCut;
								ev.text = ev.text[16 .. $].strip;
							}
							break;
						case "N":
							ev.event = EventType.Note;
							ev.note.key = words[1].to!int;
							ev.duration = words[2].to!int;
							break;
						case "S":
							ev.event = EventType.Special;
							ev.special = cast(SpecialType)words[1].to!int;
							ev.duration = words[2].to!int;
							break;
						case "A":
							calculateNoteTimes(null, 0);
							ev.event = EventType.Anchor;
							ev.time = calculateTimeOfTick(ev.tick);
							break;
						case "H":
							ev.event = EventType.NeckPosition;
							ev.position = words[1].to!int;
							break;
						default:
							// unknown?!
							continue;
					}

					if (section == Section.Sync)
						sync ~= ev;
					else if (section == Section.Events)
						events ~= ev;
					else if (section == Section.Track)
					{
//						// TODO: should specials be in the track or the events?
//						if (ev.event == EventType.Event)
//							pPart.events ~= ev; // TODO: multiple tracks may pollute this with notes, they need to be post-sorted (which means the tick can't be a delta!)
//						else
							trk.notes ~= ev;
					}
					break;
				}
			}
		}
	}

	// generate ID
	chart.id = archiveName(chart.artist, chart.name);
}
