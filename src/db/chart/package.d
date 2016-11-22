module db.chart;

import std.algorithm : min, max, map, filter, startsWith, endsWith, sort;
import std.conv : to;
import std.exception : assumeUnique;
import std.range : back, empty;
import std.string : splitLines, strip, icmp;
import std.xml;

import fuji.dbg;
import fuji.filesystem : MFFileSystem_LoadText, MFFileSystem_Save;
import fuji.fuji : MFBit;

import luad.base : noscript;

import db.chart.chart1;
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
 				if (type[] == "real-drums") // midi with 3 cymbals + hh
					preferences = [ "real-drums-2c", "pro-drums", "gh-drums", "rb-drums" ];
 				if (type[] == "real-drums-2c") // midi with 2 cymbals + hh
					preferences = [ "real-drums", "pro-drums", "gh-drums", "rb-drums" ];
 				if (type[] == "pro-drums") // RB-pro
					preferences = [ "real-drums-2c", "real-drums", "gh-drums", "rb-drums" ];
 				if (type[] == "gh-drums") // GH
					preferences = [ "pro-drums", "real-drums-2c", "real-drums", "rb-drums" ];
 				if (type[] == "rb-drums") // RB
					preferences = [ "pro-drums", "real-drums-2c", "real-drums", "gh-drums" ];
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
				parseChart1_0(this, file);
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

		sync.sort();
		auto syncElement = new Element("sync", writeSequence(sync, 2));
		doc ~= syncElement;

		events.sort();
		auto globalEvents = new Element("events", writeSequence(events, 2));
		doc ~= globalEvents;

		auto partsElement = new Element("parts");
		foreach (ref part; parts)
		{
			if (!part.variations)
				continue;

			auto partElement = new Element("part");
			partElement.tag.attr["name"] = part.part;

			part.events.sort();
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

						d.notes.sort();
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
		songPath = path ~ "/" ~ id ~ ".chart";
		MFFileSystem_Save(songPath, cast(immutable(ubyte)[])xml);
	}
}
