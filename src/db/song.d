module db.song;

import db.instrument;
import db.sequence;
import db.player;
import db.tools.range;
import db.tools.enumkvp;
import db.formats.parsers.midifile;
import db.formats.parsers.guitarprofile;
import db.scorekeepers.drums;
import db.songlibrary;

import fuji.fuji;
import fuji.material;
import fuji.sound;
import fuji.filesystem;
import fuji.heap;

import std.conv : to;
import std.range: back, empty;
import std.algorithm;
import std.string;
import std.xml;


enum GHVersion { Unknown, GH, GH2, GH3, GHWT, GHA, GHM, GH5, GHWoR, BH, RB, RB2, RB3 }

enum DrumsType
{
	Unknown = -1,

	FourDrums = 0,	// 4 drums in line
	FiveDrums,		// 3 drums, 2 cymbals
	SixDrums,		// 4 drums, 2 cymbals
	SevenDrums,		// 4 drums, 3 cymbals
	EightDrums		// 4 drums, 3 cymbals, hihat
}

struct SongPart
{
	Part part;
	Event[] events;			// events for the entire part (animation, etc)
	Variation[] variations;	// variations for the part (different versions, instrument variations (4/5/pro drums, etc), customs...
}

struct Variation
{
	string name;
	Sequence[] difficulties;	// sequences for each difficulty

	bool bHasCoopMarkers;		// GH1/GH2 style co-op (players take turns)
}

class Song
{
	this()
	{
		foreach(i, ref p; parts)
			p.part = cast(Part)i;
	}

	this(string filename)
	{
		static void readSequence(string text, ref Event[] events)
		{
			int lastTick = 0;
			foreach(l; text.splitLines.map!(l=>l.strip).filter!(l=>!l.empty))
				events ~= Event(l, lastTick);
		}

		foreach(i, ref p; parts)
			p.part = cast(Part)i;

		try
		{
			ubyte[] file = MFFileSystem_Load(filename);
			string s = cast(string)file.idup;
			MFHeap_Free(file);

			// parse xml
			auto xml = new DocumentParser(s);

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
					Part p = getEnumValue!Part(part);

					xml.onEndTag["events"] = (in Element e) { readSequence(e.text(), parts[p].events); };

					xml.onStartTag["variation"] = (ElementParser xml)
					{
						Variation v;
						v.name = xml.tag.attr["name"];

						xml.onEndTag["hasCoopMarkers"]	= (in Element e) { v.bHasCoopMarkers = !icmp(e.text(), "true"); };

						xml.onStartTag["difficulty"] = (ElementParser xml)
						{
							Sequence s = new Sequence;
							s.part = p;
							s.variation = v.name;
							s.difficulty = xml.tag.attr["name"];
							s.difficultyMeter = to!int(xml.tag.attr["meter"]);

							xml.onEndTag["sequence"] = (in Element e) { readSequence(e.text(), s.notes); };
							xml.parse();

							v.difficulties ~= s;
						};
						xml.parse();

						parts[p].variations ~= v;
					};
					xml.parse();
				};
				xml.parse();
			};
			xml.parse();
		}
		catch(Exception e)
		{
			MFDebug_Warn(2, "Couldn't load settings: " ~ e.msg);
		}
	}

	~this()
	{
		// release the resources
		release();
	}

	void saveChart(string path)
	{
		string writeSequence(Event[] events, int depth)
		{
			string prefix = "                    "[0..depth*1];
			string sequence = "\n";
			int lastTick = 0;
			foreach(e; events)
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
		if(subtitle)			doc ~= new Element("subtitle", subtitle);
								doc ~= new Element("artist", artist);
		if(album)				doc ~= new Element("album", album);
		if(year)				doc ~= new Element("year", year);
		if(packageName)			doc ~= new Element("packageName", packageName);
		if(charterName)			doc ~= new Element("charterName", charterName);

		if(tags)				doc ~= new Element("tags", tags);
		if(genre)				doc ~= new Element("genre", genre);
		if(mediaType)			doc ~= new Element("mediaType", mediaType);

		auto kvps = new Element("params");
		foreach(k, v; params)
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
		foreach(ref part; parts)
		{
			if(!part.variations)
				continue;

			auto partElement = new Element("part");
			partElement.tag.attr["name"] = getEnumFromValue(part.part);

			auto partEvents = new Element("events", writeSequence(part.events, 4));
			partElement ~= partEvents;

			foreach(v; part.variations)
			{
				auto variationElement = new Element("variation");
				variationElement.tag.attr["name"] = v.name;

				if(v.bHasCoopMarkers)	variationElement ~= new Element("hasCoopMarkers", "true");

				foreach(d; v.difficulties)
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
		MFFileSystem_Save(path ~ id ~ ".chart", cast(immutable(ubyte)[])xml);
	}

	void Prepare(Track* track)
	{
		// load song data
/*
		if(cover)
			pCover = MFMaterial_Create((songPath ~ cover).toStringz);
		if(background)
			pBackground = MFMaterial_Create((songPath ~ background).toStringz);
		if(fretboard)
			pFretboard = MFMaterial_Create((songPath ~ fretboard).toStringz);
*/

		// todo choose a source
		Track.Source* source = &track.sources[0];

		// prepare the music streams
		foreach(s; source.streams)
		{
			streams[s.type] = MFSound_CreateStream((track.contentPath ~ s.stream).toStringz, MFAudioStreamFlags.QueryLength | MFAudioStreamFlags.AllowSeeking);
			MFSound_PlayStream(streams[s.type], MFPlayFlags.BeginPaused);

			voices[s.type] = MFSound_GetStreamVoice(streams[s.type]);
//			MFSound_SetPlaybackRate(voices[i], 1.0f); // TODO: we can use this to speed/slow the song...
		}

		// calculate the note times for all tracks
		CalculateNoteTimes(events, 0);
		foreach(ref p; parts)
		{
			CalculateNoteTimes(p.events, 0);
			foreach(ref v; p.variations)
			{
				foreach(d; v.difficulties)
					CalculateNoteTimes(d.notes, 0);
			}
		}
	}

	void release()
	{
		foreach(ref s; streams)
		{
			if(s)
			{
				MFSound_DestroyStream(s);
				s = null;
			}
		}

		if(pCover)
		{
			MFMaterial_Release(pCover);
			pCover = null;
		}
		if(pBackground)
		{
			MFMaterial_Release(pBackground);
			pBackground = null;
		}
		if(pFretboard)
		{
			MFMaterial_Release(pFretboard);
			pFretboard = null;
		}
	}

	Variation* GetVariation(Part part, const(char)[] variation, bool bCreate = false)
	{
		SongPart* pPart = &parts[part];
		foreach(ref v; pPart.variations)
		{
			if(!variation || (variation && v.name[] == variation))
				return &v;
		}
		if(bCreate)
		{
			pPart.variations ~= Variation(variation.idup);
			return &pPart.variations.back;
		}
		return null;
	}

	Sequence GetDifficulty(ref Variation variation, const(char)[] difficulty)
	{
		foreach(d; variation.difficulties)
		{
			if(d.difficulty[] == difficulty)
				return d;
		}
		return null;
	}

	Sequence GetSequence(Player player, const(char)[] variation, const(char)[] difficulty)
	{
		Part part = player.input.part;
		SongPart* pPart = &parts[part];
		if(pPart.variations.empty)
			return null;

		Variation* var;
		bool bFound;

		string preferences[];
		size_t preference;

		// TODO: should there be a magic name for the default variation rather than the first one?
		//...

		if(part == Part.Drums)
		{
			// each drums configuration has a different preference for conversion
			auto device = player.input.device;
			if((device.features & MFBit!(DrumFeatures.Has4Drums)) && (device.features & MFBit!(DrumFeatures.Has3Cymbals)) && (device.features & MFBit!(DrumFeatures.HasHiHat)))
				preferences = [ "-8drums", "-7drums", "-6drums", "-5drums", "-4drums" ];
			else if((device.features & MFBit!(DrumFeatures.Has4Drums)) && (device.features & MFBit!(DrumFeatures.Has2Cymbals)) && (device.features & MFBit!(DrumFeatures.HasHiHat)))
				preferences = [ "-8drums", "-7drums", "-6drums", "-5drums", "-4drums" ];
			else if((device.features & MFBit!(DrumFeatures.Has4Drums)) && (device.features & MFBit!(DrumFeatures.Has3Cymbals)))
				preferences = [ "-7drums", "-8drums", "-6drums", "-5drums", "-4drums" ];
			else if((device.features & MFBit!(DrumFeatures.Has4Drums)) && (device.features & MFBit!(DrumFeatures.Has2Cymbals)))
				preferences = [ "-6drums", "-7drums", "-8drums", "-5drums", "-4drums" ];
			else if(device.features & MFBit!(DrumFeatures.Has2Cymbals))
				preferences = [ "-5drums", "-6drums", "-7drums", "-8drums", "-4drums" ];
			else if(device.features & MFBit!(DrumFeatures.Has4Drums))
				preferences = [ "-4drums", "-7drums", "-8drums", "-6drums", "-5drums" ];
			else
				assert(false, "What kind of kit is this?!");

			// find the appropriate variation for the player's kit
			outer: foreach(i, pref; preferences)
			{
				foreach(ref v; pPart.variations)
				{
					if(v.name.endsWith(pref))
					{
						if(!variation || (variation && v.name.startsWith(variation)))
						{
							var = &v;
							bFound = true;
							preference = i;
							break outer;
						}
					}
				}
			}
		}
		else
		{
			foreach(ref v; pPart.variations)
			{
				if(!variation || (variation && v.name == variation))
				{
					var = &v;
					bFound = true;
					break;
				}
			}
		}

		if(!bFound)
			return null;

		Sequence s;
		if(difficulty)
			s = GetDifficulty(*var, difficulty);

		// TODO: should there be some fallback logic if a requested difficulty isn't available?
		//       can we rank difficulties by magic name strings?
		if(!s)
			s = var.difficulties.back;

		if(part == Part.Drums && preference != 0)
		{
			// fabricate a sequence for the players kit
			s = FabricateSequence(this, preferences[0], s);
		}

		return s;
	}

	void Pause(bool bPause)
	{
		foreach(s; streams)
			if(s)
				MFSound_PauseStream(s, bPause);
	}

	void Seek(float offsetInSeconds)
	{
		foreach(s; streams)
			if(s)
				MFSound_SeekStream(s, offsetInSeconds);
	}

	void SetVolume(Part part, float volume)
	{
		// TODO: figure how parts map to playing streams
	}

	void SetPan(Part part, float pan)
	{
		// TODO: figure how parts map to playing streams
	}

	bool IsPartPresent(Part part)
	{
		return parts[part].variations != null;
	}

	int GetLastNoteTick()
	{
		// find the last event in the song
		int lastTick = sync.empty ? 0 : sync.back.tick;
		foreach(ref p; parts)
		{
			foreach(ref v; p.variations)
			{
				foreach(d; v.difficulties)
					lastTick = max(lastTick, d.notes.empty ? 0 : d.notes.back.tick);
			}
		}
		return lastTick;
	}

	@property int startUsPB() const pure nothrow
	{
		foreach(e; sync)
		{
			if(e.tick != 0)
				break;
			if(e.event == EventType.BPM || e.event == EventType.Anchor)
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

		foreach(si, ref sev; sync)
		{
			if(sev.event == EventType.BPM || sev.event == EventType.Anchor)
			{
				tempoTime = cast(long)(sev.tick - offset)*microsecondsPerBeat/resolution;

				// calculate event time (if event is not an anchor)
				if(sev.event != EventType.Anchor)
					sev.time = playTime + tempoTime;

				// calculate note times
				ptrdiff_t note = stream.GetNextEvent(offset);
				if(note != -1)
				{
					for(; note < stream.length && stream[note].tick < sev.tick; ++note)
						stream[note].time = playTime + cast(long)(stream[note].tick - offset)*microsecondsPerBeat/resolution;
				}

				// increment play time to BPM location
				if(sev.event == EventType.Anchor)
					playTime = sev.time;
				else
					playTime += tempoTime;

				// find if next event is an anchor or not
				for(auto i = si + 1; i < sync.length && sync[i].event != EventType.BPM; ++i)
				{
					if(sync[i].event == EventType.Anchor)
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
		if(note != -1)
		{
			for(; note < stream.length; ++note)
				stream[note].time = playTime + cast(long)(stream[note].tick - offset)*microsecondsPerBeat/resolution;
		}
	}

	long CalculateTimeOfTick(int tick)
	{
		int offset, currentUsPB;
		long time;

		Event *pEv = GetMostRecentSyncEvent(tick);
		if(pEv)
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

		if(offset < tick)
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

		if(e)
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

		if(pUsPerBeat)
			*pUsPerBeat = currentUsPerBeat;

		return lastEventOffset + cast(int)((time - lastEventTime)*resolution/currentUsPerBeat);
	}

	// data...
//	string songPath;

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
	SongPart[Part.Count] parts;

	MFMaterial* pCover;
	MFMaterial* pBackground;
	MFMaterial* pFretboard;

	MFAudioStream*[Streams.Count] streams;
	MFVoice*[Streams.Count] voices;
}


// Binary search on the events
// before: true = return event one before requested time, false = return event one after requested time
// type: "tick", "time" to search by tick or by time
private ptrdiff_t GetEventForOffset(bool before, bool byTime)(Event[] events, long offset)
{
	enum member = byTime ? "time" : "tick";

	if(events.empty)
		return -1;

	// get the top bit
	size_t i = events.length, topBit = 0;
	while((i >>= 1))
		++topBit;
	i = topBit = 1 << topBit;

	// binary search bitchez!!
	ptrdiff_t target = -1;
	while(true)
	{
		if(i >= events.length) // if it's an invalid index
		{
			i = (i & ~topBit) | topBit>>1;
		}
		else if(mixin("events[i]." ~ member) == offset)
		{
			// return the first in sequence
			while(i > 0 && mixin("events[i-1]." ~ member) == mixin("events[i]." ~ member))
				--i;
			return i;
		}
		else if(mixin("events[i]." ~ member) > offset)
		{
			static if(!before)
				target = i;
			i = (i & ~topBit) | topBit>>1;
		}
		else
		{
			static if(before)
				target = i;
			i |= topBit>>1;
		}
		if(!topBit)
			break;
		topBit >>= 1;
	}

	return target;
}

private template AllIs(Ty, T...)
{
	static if(T.length == 0)
		enum AllIs = true;
	else
		enum AllIs = is(T[0] == Ty) && AllIs!(T[1..$], Ty);
}

// skip over events of specified types
ptrdiff_t SkipEvents(bool reverse = false, Types...)(Event[] events, ptrdiff_t e, Types types) if(AllIs!(E.EventType, Types))
{
	outer: for(; (reverse && e >= 0) || (!reverse && e < events.length); e += reverse ? -1 : 1)
	{
		foreach(t; types)
		{
			if(events[e].event == t)
				continue outer;
		}
		return e;
	}
	return -1;
}

// skip events until we find one we're looking for
ptrdiff_t SkipToEvents(bool reverse = false, Types...)(Event[] events, ptrdiff_t e, Types types) if(AllIs!(EventType, Types))
{
	for(; (reverse && e >= 0) || (!reverse && e < events.length); e += reverse ? -1 : 1)
	{
		foreach(t; types)
		{
			if(events[e].event == t)
				return e;
		}
	}
	return -1;
}

// get all events at specified tick
Event[] EventsAt(Event[] events, int tick)
{
	ptrdiff_t i = events.GetEventForOffset!(false, false)(tick);
	if(i != tick)
		return null;
	auto e = i;
	while(e < events.length-1 && events[e+1].tick == events[e].tick)
		++e;
	return events[i..e+1];
}

ptrdiff_t FindEvent(Event[] events, EventType type, int tick, int key = -1)
{
	// find the events at the requested offset
	auto ev = events.EventsAt(tick);
	if(!ev)
		return -1;

	// match the other conditions
	foreach(ref e; ev)
	{
		if(!type || e.event == type)
		{
			if(key == -1 || e.note.key == key)
				return &e - events.ptr; // return it as an index (TODO: should this return a ref instead?)
		}
	}
	return -1;
}

private ptrdiff_t GetEvent(bool reverse, bool byTime, Types...)(Event[] events, long offset, Types types) if(AllIs!(EventType, Types))
{
	ptrdiff_t e = events.GetEventForOffset!(reverse, byTime)(offset);
	if(e < 0 || Types.length == 0)
		return e;
	return events.SkipToEvents!reverse(e, types);
}

ptrdiff_t GetNextEvent(Types...)(Event[] events, int tick, Types types) if(AllIs!(EventType, Types))
{
	return events.GetEvent!(false, false)(tick, types);
}

ptrdiff_t GetNextEventByTime(Types...)(Event[] events, long time, Types types) if(AllIs!(EventType, Types))
{
	return events.GetEvent!(false, true)(time, types);
}

ptrdiff_t GetMostRecentEvent(Types...)(Event[] events, int tick, Types types) if(AllIs!(EventType, Types))
{
	return events.GetEvent!(true, false)(tick, types);
}

ptrdiff_t GetMostRecentEventByTime(Types...)(Event[] events, long time, Types types) if(AllIs!(EventType, Types))
{
	return events.GetEvent!(true, true)(time, types);
}

Event[] Between(Event[] events, int startTick, int endTick)
{
	assert(endTick >= startTick, "endTick must be greater than startTick");
	size_t first = events.GetNextEvent(startTick);
	size_t last = events.GetNextEvent(endTick+1);
	if(first == -1)
		return events[$..$];
	else if(last == -1)
		return events[first..$];
	else
		return events[first..last];
}

Event[] BetweenTimes(Event[] events, long startTime, long endTime)
{
	assert(endTime >= startTime, "endTime must be greater than startTime");
	size_t first = events.GetNextEventByTime(startTime);
	size_t last = events.GetNextEventByTime(endTime+1);
	if(first == -1)
		return events[$..$];
	else if(last == -1)
		return events[first..$];
	else
		return events[first..last];
}
