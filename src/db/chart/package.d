module db.chart;

import std.algorithm : min, max, map, filter, startsWith, endsWith;
import std.conv : to;
import std.exception : assumeUnique;
import std.range : back, empty;
import std.string : splitLines, strip, icmp;
import std.xml;

import fuji.dbg;
import fuji.filesystem : MFFileSystem_LoadText, MFFileSystem_Save;
import fuji.fuji : MFBit;

import luad.base : noscript;

import db.library : archiveName;
import db.instrument : Instrument;
import db.instrument.drums;

public import db.chart.part;
public import db.chart.event;
public import db.chart.track;


class Chart
{
@noscript:
	// data
	string songPath;

	string id;
	string name;
	string variant;					// used for things like radio edits, live performances, etc
	string subtitle;
	string artist;
	string album;
	string year;
	string packageName;				// where did the song come from? (eg, "Rock Band II", "Guitar Hero Metallica", "Rush DLC", etc)
	string charterName;

	string tags;					// string tags for sorting/filtering
	string genre;
	string mediaType;				// media type for pfx theme purposes (cd/casette/vinyl/etc)

	string[string] params;			// optional key-value pairs (much data taken from the original .ini files, might be useful in future)

	// song data
	int resolution;

	long startOffset;				// starting offset, in microseconds

	Event[] sync;					// song sync stuff
	Event[] events;					// general song/venue events (sections, effects, lighting, etc?)
	Part[string] parts;


	// methods
	this()
	{
	}

	this(string filename)
	{
		loadChart(filename);
	}

	void prepare()
	{
		// calculate the note times for all tracks
		calculateNoteTimes(events, 0);
		foreach (ref p; parts)
		{
			calculateNoteTimes(p.events, 0);
			foreach (ref v; p.variations)
			{
				foreach (d; v.difficulties)
					calculateNoteTimes(d.notes, 0);
			}
		}
	}

	bool hasPart(const(char)[] part)
	{
		return (part in parts) != null;
	}

	Part* getPart(const(char)[] name, bool create = false)
	{
		Part* p = name in parts;
		if (!p && create)
		{
			string iname = name.idup;
			parts[iname] = Part(iname);
			p = name in parts;
		}
		return p;
	}
	Variation* getVariation(const(char)[] part, const(char)[] variationType, const(char)[] variationName, bool create = false)
	{
		Part* pPart = getPart(part, create);
		if (!pPart)
			return null;
		return pPart.variation(variationType, variationName, create);
	}
	Track getTrack(const(char)[] part, const(char)[] type, const(char)[] variation, Difficulty difficulty)
	{
		Variation* pVariation = getVariation(part, type, variation);
		if (!pVariation)
			return null;
		return pVariation.difficulty(difficulty);
	}

	Track createTrack(const(char)[] part, const(char)[] type, const(char)[] variation, Difficulty difficulty)
	{
		Variation* pVariation = getVariation(part, type, variation, true);

		Track trk = new Track();
		trk.part = part.idup;
		trk.variationType = type.idup;
		trk.variationName = variation.idup;
		trk.difficulty = difficulty;
		pVariation.addDifficulty(trk);

		return trk;
	}

	Track getTrackForPlayer(const(char)[] part, const(char)[] type, const(char)[] variation, Difficulty difficulty)
	{
		import db.scorekeepers.drums : fabricateTrack;

		Part* pPart = getPart(part);
		if (!pPart || pPart.variations.empty)
			return null;

		Variation *pVar = pPart.bestVariationForType(type, variation);
		if (!pVar)
		{
			// for drums, we can synthesize a track from other kit types
			if (type[] == "drums")
			{
				// each drums configuration has a different preference for conversion
				string[] preferences;
 				if (type[] == "8-drums") // midi with 3 cymbals + hh
					preferences = [ "6-drums-hh", "7-drums", "5-drums", "4-drums" ];
 				if (type[] == "6-drums-hh") // midi with 2 cymbals + hh
					preferences = [ "8-drums", "7-drums", "5-drums", "4-drums" ];
 				if (type[] == "7-drums") // RB-pro
					preferences = [ "6-drums-hh", "8-drums", "5-drums", "4-drums" ];
 				if (type[] == "5-drums") // GH
					preferences = [ "7-drums", "6-drums-hh", "8-drums", "4-drums" ];
 				if (type[] == "4-drums") // RB
					preferences = [ "7-drums", "6-drums-hh", "8-drums", "5-drums" ];
				else
					assert(false, "What kind of kit is this?!");

				// find the best variation for the player's kit...

				// find users preferred variation if specified
				if (variation)
				{
					foreach (pref; preferences)
					{
						pVar = pPart.variation(pref, variation);
						if (pVar)
							break;
					}
				}
				if (!pVar)
				{
					// prefer default variation
					foreach (pref; preferences)
					{
						pVar = pPart.variation(pref, null);
						if (pVar)
							break;
					}
				}
				if (!pVar)
				{
					// just pick ANY variation for the most appropriate type...
					foreach (pref; preferences)
					{
						pVar = pPart.bestVariationForType(pref, null);
						if (pVar)
							break;
					}
				}

				if (pVar)
				{
					difficulty = pVar.nearestDifficulty(difficulty);
					if (difficulty != Difficulty.Unknown)
						return fabricateTrack(this, pVar.type, pVar.difficulty(difficulty));
				}
			}
			return null;
		}

		Difficulty diff = pVar.nearestDifficulty(difficulty);
		if (diff == Difficulty.Unknown)
			return null;

		return pVar.difficulty(diff);
	}

	int getLastNoteTick()
	{
		// find the last event in the song
		int lastTick = sync.empty ? 0 : sync.back.tick;
		foreach (ref p; parts)
		{
			foreach (ref v; p.variations)
			{
				foreach (d; v.difficulties)
					lastTick = max(lastTick, d.notes.empty ? 0 : d.notes.back.tick);
			}
		}
		return lastTick;
	}

	@property int startUsPB() const pure nothrow
	{
		foreach (ref e; sync)
		{
			if (e.tick != 0)
				break;
			if (e.event == EventType.BPM || e.event == EventType.Anchor)
				return e.bpm.usPerBeat;
		}

		return 60_000_000/120; // microseconds per beat
	}

	void calculateNoteTimes(Event[] stream, int startTick)
	{
		int offset = 0;
		uint microsecondsPerBeat = startUsPB;
		long playTime = startOffset;
		long tempoTime = 0;

		foreach (si, ref sev; sync)
		{
			if (sev.event == EventType.BPM || sev.event == EventType.Anchor)
			{
				tempoTime = cast(long)(sev.tick - offset)*microsecondsPerBeat/resolution;

				// calculate event time (if event is not an anchor)
				if (sev.event != EventType.Anchor)
					sev.time = playTime + tempoTime;

				// calculate note times
				ptrdiff_t note = stream.GetNextEvent(offset);
				if (note != -1)
				{
					for (; note < stream.length && stream[note].tick < sev.tick; ++note)
						stream[note].time = playTime + cast(long)(stream[note].tick - offset)*microsecondsPerBeat/resolution;
				}

				// increment play time to BPM location
				if (sev.event == EventType.Anchor)
					playTime = sev.time;
				else
					playTime += tempoTime;

				// find if next event is an anchor or not
				for (auto i = si + 1; i < sync.length && sync[i].event != EventType.BPM; ++i)
				{
					if (sync[i].event == EventType.Anchor)
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
		if (note != -1)
		{
			for (; note < stream.length; ++note)
				stream[note].time = playTime + cast(long)(stream[note].tick - offset)*microsecondsPerBeat/resolution;
		}
	}

	Event* getMostRecentSyncEvent(int tick)
	{
		auto e = sync.GetMostRecentEvent(tick, EventType.BPM, EventType.Anchor);
		return e < 0 ? null : &sync[e];
	}

	Event* getMostRecentSyncEventTime(long time)
	{
		auto e = sync.GetMostRecentEventByTime(time, EventType.BPM, EventType.Anchor);
		return e < 0 ? null : &sync[e];
	}

	long calculateTimeOfTick(int tick)
	{
		int offset, currentUsPB;
		long time;

		Event *pEv = getMostRecentSyncEvent(tick);
		if (pEv)
		{
			time = pEv.time;
			offset = pEv.tick;
			currentUsPB = pEv.bpm.usPerBeat;
		}
		else
		{
			time = startOffset;
			offset = 0;
			currentUsPB = startUsPB;
		}

		if (offset < tick)
			time += cast(long)(tick - offset)*currentUsPB/resolution;

		return time;
	}

	int calculateTickAtTime(long time, int *pUsPerBeat = null)
	{
		uint currentUsPerBeat;
		long lastEventTime;
		int lastEventOffset;

		Event *e = getMostRecentSyncEventTime(time);

		if (e)
		{
			lastEventTime = e.time;
			lastEventOffset = e.tick;
			currentUsPerBeat = e.bpm.usPerBeat;
		}
		else
		{
			lastEventTime = startOffset;
			lastEventOffset = 0;
			currentUsPerBeat = startUsPB;
		}

		if (pUsPerBeat)
			*pUsPerBeat = currentUsPerBeat;

		return lastEventOffset + cast(int)((time - lastEventTime)*resolution/currentUsPerBeat);
	}

	void insertSyncEvent(ref Event ev)
	{
		if (sync.FindEvent(ev.event, ev.tick) != -1)
		{
			// there's already a sync event here!
			return;
		}

		ev.time = calculateTimeOfTick(ev.tick);

		ptrdiff_t i = sync.GetNextEvent(ev.tick + 1);
		if (i == -1)
			sync ~= ev;
		else
		{
			sync = sync[0 .. i] ~ ev ~ sync[i .. $];
			calculateNoteTimes(sync, ev.tick);
		}
	}
	void insertEvent(ref Event ev, Part *pPart = null)
	{
		ev.time = calculateTimeOfTick(ev.tick);

		Event[]* pEv = pPart ? &pPart.events : &events;

		ptrdiff_t i = (*pEv).GetNextEvent(ev.tick + 1);
		if (i == -1)
			*pEv ~= ev;
		else
			*pEv = (*pEv)[0 .. i] ~ ev ~ (*pEv)[i .. $];
	}
	void insertTrackEvent(Track trk, ref Event ev)
	{
		ev.time = calculateTimeOfTick(ev.tick);

		ptrdiff_t i = trk.notes.GetNextEvent(ev.tick + 1);
		if (i == -1)
			trk.notes ~= ev;
		else
			trk.notes = trk.notes[0 .. i] ~ ev ~ trk.notes[i .. $];
	}

	void removeNote(Track trk, int tick, int key)
	{
		auto i = trk.notes.FindEvent(EventType.Note, tick, key);
		if (i != -1)
			removeEvent(trk, &trk.notes[i]);
	}
	void removeEvent(Track trk, Event* pEv)
	{
		ptrdiff_t i = pEv - trk.notes.ptr;
		if (i >= 0 && i < trk.notes.length)
			trk.notes = trk.notes[0 .. i] ~ trk.notes[i+1 .. $];
	}


	// worker stuff

	private void loadChart(string filename)
	{
		static void readSequence(string text, ref Event[] events)
		{
			int lastTick = 0;
			foreach (l; text.splitLines.map!(l=>l.strip).filter!(l=>!l.empty))
				events ~= Event(l, lastTick);
		}

		try
		{
			string file = MFFileSystem_LoadText(filename).assumeUnique;

			// parse xml
			auto xml = new DocumentParser(file);
			if(!xml.tag)
			{
				parseChart1_0(file);
				songPath = filename;
				return;
			}

			if (xml.tag.name[] != "chart")
				throw new Exception("Not a .chart file!");
			int chartVer = cast(int)(xml.tag.attr["version"].to!float*100);

			xml.onEndTag["id"]				= (in Element e) { id			= e.text(); };
			xml.onEndTag["name"]			= (in Element e) { name			= e.text(); };
			xml.onEndTag["subtitle"]		= (in Element e) { subtitle		= e.text(); };
			xml.onEndTag["artist"]			= (in Element e) { artist		= e.text(); };
			xml.onEndTag["album"]			= (in Element e) { album		= e.text(); };
			xml.onEndTag["year"]			= (in Element e) { year			= e.text(); };
			xml.onEndTag["packageName"]		= (in Element e) { packageName	= e.text(); };
			xml.onEndTag["charterName"]		= (in Element e) { charterName	= e.text(); };
			xml.onEndTag["tags"]			= (in Element e) { tags			= e.text(); };
			xml.onEndTag["genre"]			= (in Element e) { genre		= e.text(); };
			xml.onEndTag["mediaType"]		= (in Element e) { mediaType	= e.text(); };

			xml.onStartTag["params"] = (ElementParser xml)
			{
				xml.onEndTag["param"] = (in Element e)
				{
					string k = e.tag.attr["key"];
					string v = e.text();
					params[k] = v;
				};
				xml.parse();
			};

			xml.onEndTag["resolution"]	= (in Element e) { resolution	= to!int(e.text()); };
			xml.onEndTag["startOffset"]	= (in Element e) { startOffset	= to!long(e.text()); };

			xml.onEndTag["sync"]		= (in Element e) { readSequence(e.text(), sync); };
			xml.onEndTag["events"]		= (in Element e) { readSequence(e.text(), events); };

			xml.onStartTag["parts"] = (ElementParser xml)
			{
				xml.onStartTag["part"] = (ElementParser xml)
				{
					string part = xml.tag.attr["name"];

					xml.onEndTag["events"] = (in Element e) { readSequence(e.text(), getPart(part, true).events); };

					xml.onStartTag["variation"] = (ElementParser xml)
					{
						Variation v;
						if ("type" in xml.tag.attr)
							v.type = xml.tag.attr["type"];
						if ("name" in xml.tag.attr)
							v.name= xml.tag.attr["name"];

						xml.onEndTag["hasCoopMarkers"]	= (in Element e) { v.bHasCoopMarkers = !icmp(e.text(), "true"); };

						xml.onStartTag["difficulty"] = (ElementParser xml)
						{
							Track s = new Track;
							s.part = part;
							s.variationType = v.type;
							s.variationName = v.name;
							s.difficulty = to!Difficulty(xml.tag.attr["level"]);
							const(string)* pName = "name" in xml.tag.attr;
							if (pName)
								s.difficultyName = *pName;
							s.difficultyMeter = to!int(xml.tag.attr["meter"]);

							xml.onEndTag["sequence"] = (in Element e) { readSequence(e.text(), s.notes); };
							xml.parse();

							v.addDifficulty(s);
						};
						xml.parse();

						getPart(part, true).variations ~= v;
					};
					xml.parse();
				};
				xml.parse();
			};
			xml.parse();

			songPath = filename;
		}
		catch (Exception e)
		{
			MFDebug_Warn(2, "Couldn't load settings: " ~ e.msg);
		}
	}

	private void parseChart1_0(string file)
	{
		import std.string : lineSplitter;
		import std.algorithm : splitter, copy;

		// TODO: parse .chart v1.0
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

		params["source_format"] = ".chart_1_0";

		foreach (line; file.lineSplitter)
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
					case "EasyDrums":			trk = createTrack("drums", "5-drums", null, Difficulty.Easy);									section = Section.Track;	break;
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
					case "MediumDrums":			trk = createTrack("drums", "5-drums", null, Difficulty.Medium);									section = Section.Track;	break;
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
					case "HardDrums":			trk = createTrack("drums", "5-drums", null, Difficulty.Hard);									section = Section.Track;	break;
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
					case "ExpertDrums":			trk = createTrack("drums", "5-drums", null, Difficulty.Expert);									section = Section.Track;	break;
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
//							// TODO: should specials be in the track or the events?
//							if (ev.event == EventType.Event)
//								pPart.events ~= ev; // TODO: multiple tracks may pollute this with notes, they need to be post-sorted (which means the tick can't be a delta!)
//							else
								trk.notes ~= ev;
						}
						break;
					}
				}
			}
		}

		// generate ID
		id = archiveName(artist, name);
	}

	void saveChart(string path)
	{
		import std.array : join;

		string writeSequence(Event[] events, int depth)
		{
			string prefix = "                    "[0..depth*1];
			string sequence = "\n";
			int lastTick = 0;
			foreach (ref e; events)
			{
				sequence ~= e.toString(lastTick, prefix, "\n");
				lastTick = e.tick;
			}
			return sequence ~ prefix[0..$-1];
		}

		id = archiveName(artist, name, variant);

		// TODO: develop a format for the note chart files...
		auto doc = new Document(new Tag("chart"));
		doc.tag.attr["version"] = "2.0";

		doc ~= new Element("id", id);
		doc ~= new Element("name", name);
		if (subtitle)			doc ~= new Element("subtitle", subtitle);
		doc ~= new Element("artist", artist);
		if (album)				doc ~= new Element("album", album);
		if (year)				doc ~= new Element("year", year);
		if (packageName)		doc ~= new Element("packageName", packageName);
		if (charterName)		doc ~= new Element("charterName", charterName);

		if (tags)				doc ~= new Element("tags", tags);
		if (genre)				doc ~= new Element("genre", genre);
		if (mediaType)			doc ~= new Element("mediaType", mediaType);

		auto kvps = new Element("params");
		foreach (k, v; params)
		{
			auto kvp = new Element("param", v);
			kvp.tag.attr["key"] = k;
			kvps ~= kvp;
		}
		doc ~= kvps;

		doc ~= new Element("resolution", to!string(resolution));
		doc ~= new Element("startOffset", to!string(startOffset));

		auto syncElement = new Element("sync", writeSequence(sync, 2));
		doc ~= syncElement;

		auto globalEvents = new Element("events", writeSequence(events, 2));
		doc ~= globalEvents;

		auto partsElement = new Element("parts");
		foreach (ref part; parts)
		{
			if (!part.variations)
				continue;

			auto partElement = new Element("part");
			partElement.tag.attr["name"] = part.part;

			auto partEvents = new Element("events", writeSequence(part.events, 4));
			partElement ~= partEvents;

			foreach (ref v; part.variations)
			{
				auto variationElement = new Element("variation");
				if (v.type)
					variationElement.tag.attr["type"] = v.type;
				if (v.name)
					variationElement.tag.attr["name"] = v.name;

				if (v.bHasCoopMarkers)	variationElement ~= new Element("hasCoopMarkers", "true");

				foreach (d; v.difficulties)
				{
					if (d.notes)
					{
						auto difficultyElement = new Element("difficulty");
						difficultyElement.tag.attr["level"] = to!string(d.difficulty);
						if (d.difficultyName)
							difficultyElement.tag.attr["name"] = d.difficultyName;
						difficultyElement.tag.attr["meter"] = to!string(d.difficultyMeter);

						difficultyElement ~= new Element("sequence", writeSequence(d.notes, 6));

						variationElement ~= difficultyElement;
					}
				}

				partElement ~= variationElement;
			}

			partsElement ~= partElement;
		}
		doc ~= partsElement;

		string xml = join(doc.pretty(1),"\n");
		songPath = path ~ id ~ ".chart";
		MFFileSystem_Save(songPath, cast(immutable(ubyte)[])xml);
	}
}
