module db.chart;

import std.algorithm : max, map, filter, startsWith, endsWith;
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
	this()
	{
	}

	this(string filename)
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

					xml.onEndTag["events"] = (in Element e) { readSequence(e.text(), getPart(part).events); };

					xml.onStartTag["variation"] = (ElementParser xml)
					{
						Variation v;
						v.name = xml.tag.attr["name"];

						xml.onEndTag["hasCoopMarkers"]	= (in Element e) { v.bHasCoopMarkers = !icmp(e.text(), "true"); };

						xml.onStartTag["difficulty"] = (ElementParser xml)
						{
							Track s = new Track;
							s.part = part;
							s.variation = v.name;
							s.difficulty = xml.tag.attr["name"];
							s.difficultyMeter = to!int(xml.tag.attr["meter"]);

							xml.onEndTag["sequence"] = (in Element e) { readSequence(e.text(), s.notes); };
							xml.parse();

							v.difficulties ~= s;
						};
						xml.parse();

						getPart(part).variations ~= v;
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

	void parseChart1_0(string file)
	{
		// TODO: parse .chart v1.0
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
				variationElement.tag.attr["name"] = v.name;

				if (v.bHasCoopMarkers)	variationElement ~= new Element("hasCoopMarkers", "true");

				foreach (d; v.difficulties)
				{
					auto difficultyElement = new Element("difficulty");
					difficultyElement.tag.attr["name"] = d.difficulty;
					difficultyElement.tag.attr["meter"] = to!string(d.difficultyMeter);

					difficultyElement ~= new Element("sequence", writeSequence(d.notes, 6));

					variationElement ~= difficultyElement;
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

	void prepare()
	{
		// calculate the note times for all tracks
		CalculateNoteTimes(events, 0);
		foreach (ref p; parts)
		{
			CalculateNoteTimes(p.events, 0);
			foreach (ref v; p.variations)
			{
				foreach (d; v.difficulties)
					CalculateNoteTimes(d.notes, 0);
			}
		}
	}

	ref Part getPart(const(char)[] name)
	{
		Part* p = name in parts;
		if (!p)
		{
			string iname = name.idup;
			parts[iname] = Part(iname);
			p = name in parts;
		}
		return *p;
	}

	Variation* getVariation(ref Part part, const(char)[] variation, bool bCreate = false)
	{
		foreach (ref v; part.variations)
		{
			if (!variation || (variation && v.name[] == variation))
				return &v;
		}
		if (bCreate)
		{
			part.variations ~= Variation(variation.idup);
			return &part.variations.back;
		}
		return null;
	}

	Variation* getVariation(string part, const(char)[] variation, bool bCreate = false)
	{
		Part* pPart = part in parts;
		if (!pPart)
			return null;
		return getVariation(*pPart, variation, bCreate);
	}

	Track GetDifficulty(ref Variation variation, const(char)[] difficulty)
	{
		foreach (d; variation.difficulties)
		{
			if (d.difficulty[] == difficulty)
				return d;
		}
		return null;
	}

	Track GetSequence(string part, Instrument instrument, const(char)[] variation, const(char)[] difficulty)
	{
		Part* pPart = part in parts;
		if (!pPart || pPart.variations.empty)
			return null;

		Variation* var;
		bool bFound;

		string[] preferences;
		size_t preference;

		// TODO: should there be a magic name for the default variation rather than the first one?
		//...

		if (part[] == "drums")
		{
			// each drums configuration has a different preference for conversion
			auto i = instrument;
			if ((i.features & MFBit!(DrumFeatures.Has4Drums)) && (i.features & MFBit!(DrumFeatures.Has3Cymbals)) && (i.features & MFBit!(DrumFeatures.HasHiHat)))
				preferences = [ "-8drums", "-7drums", "-6drums", "-5drums", "-4drums" ];
			else if ((i.features & MFBit!(DrumFeatures.Has4Drums)) && (i.features & MFBit!(DrumFeatures.Has2Cymbals)) && (i.features & MFBit!(DrumFeatures.HasHiHat)))
				preferences = [ "-8drums", "-7drums", "-6drums", "-5drums", "-4drums" ];
			else if ((i.features & MFBit!(DrumFeatures.Has4Drums)) && (i.features & MFBit!(DrumFeatures.Has3Cymbals)))
				preferences = [ "-7drums", "-8drums", "-6drums", "-5drums", "-4drums" ];
			else if ((i.features & MFBit!(DrumFeatures.Has4Drums)) && (i.features & MFBit!(DrumFeatures.Has2Cymbals)))
				preferences = [ "-6drums", "-7drums", "-8drums", "-5drums", "-4drums" ];
			else if (i.features & MFBit!(DrumFeatures.Has2Cymbals))
				preferences = [ "-5drums", "-6drums", "-7drums", "-8drums", "-4drums" ];
			else if (i.features & MFBit!(DrumFeatures.Has4Drums))
				preferences = [ "-4drums", "-7drums", "-8drums", "-6drums", "-5drums" ];
			else
				assert(false, "What kind of kit is this?!");

			// find the appropriate variation for the player's kit
			outer: foreach (j, pref; preferences)
			{
				foreach (ref v; pPart.variations)
				{
					if (v.name.endsWith(pref))
					{
						if (!variation || (variation && v.name.startsWith(variation)))
						{
							var = &v;
							bFound = true;
							preference = j;
							break outer;
						}
					}
				}
			}
		}
		else
		{
			foreach (ref v; pPart.variations)
			{
				if (!variation || (variation && v.name == variation))
				{
					var = &v;
					bFound = true;
					break;
				}
			}
		}

		if (!bFound)
			return null;

		Track s;
		if (difficulty)
			s = GetDifficulty(*var, difficulty);

		// TODO: should there be some fallback logic if a requested difficulty isn't available?
		//       can we rank difficulties by magic name strings?
		if (!s)
			s = var.difficulties.back;

		if (part[] == "drums" && preference != 0)
		{
			import db.scorekeepers.drums : fabricateTrack;
			// fabricate a track for the players kit
			s = fabricateTrack(this, preferences[0], s);
		}

		return s;
	}

	bool IsPartPresent(string part)
	{
		return (part in parts) != null;
	}

	int GetLastNoteTick()
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

	void CalculateNoteTimes(E)(E[] stream, int startTick)
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

	long CalculateTimeOfTick(int tick)
	{
		int offset, currentUsPB;
		long time;

		Event *pEv = GetMostRecentSyncEvent(tick);
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

	// data...
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
}
