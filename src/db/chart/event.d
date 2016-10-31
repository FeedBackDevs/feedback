module db.chart.event;

import std.range : empty;

enum EventType
{
	Unknown,

	BPM,
	Anchor,
	Freeze,
	TimeSignature,

	Note,				// a regular note
	GuitarNote,			// notes for pro guitar modes (string + fret)
	Lyric,				// lyrics
	Special,			// special sections
	Event,				// text events
	Section,			// song section names
	DrumAnimation,		// drum animation
	Chord,				// the guitar chord in use
	NeckPosition,		// ranging 0-19, even spatial intervals between frets 0 and 12
	KeyboardPosition,	// the key appearing at the left of the keyboard
	Lighting,			// lighting events
	DirectedCut,		// directed camera cut
	MIDI,				// raw midi event (for stuff we haven't decoded yet)
}

enum SpecialType
{
	Boost,			// star power/overdrive
	LeftPlayer,		// GH1/2 co-op mode
	RightPlayer,	// GH1/2 co-op mode
	Slide,			// GH4 slider
	Solo,			// RB solo
	FreeStyle,
	DrumRoll,
	SpecialDrumRoll,
	Trill,			// RB trill guitar, pro keys
	Tremolo,		// RB guitar
	Glissando		// RB pro keys
}

enum DrumAnimation
{
	Kick_RF, // 24 C0 = Kick hit w/RF
	HatUp_LF, // 25 C#0 = Hi-Hat pedal up (hat open) w/LF. The hat will stay open for the duration of the note. The default is pedal down (hat closed).
	Snare_LH, // 26 D0 = Snare hit w/LH
	Snare_RH, // 27 D#0 = Snare hit w/RH
	Snare_Soft_LH, // 28 (E0) is a soft snare hit with the left hand
	Snare_Soft_RH, // 29 (F0) is a soft snare hit with the right hand
	Hat_LH, // 30 F#0 = Hi-Hat hit w/LH
	Hat_RH, // 31 G0 = Hi-Hat hit w/RH
	Percussion_RH, // 32 G#0 = Percussion w/ RH
	Unknown, // NOTE: 33 is some unknown event?
	Crash1_LH, // 34 A#0 = Crash1 hard hit w/LH
	Crash1_Soft_LH, // 35 B0 = Crash1 soft hit w/LH
	Crash1_RH, // 36 C1 = Crash1 hard hit w/RH
	Crash1_Soft_RH, // 37 C#1 = Crash1 (near Hi-Hat) soft hit w/RH
	Crash2_RH, // 38 D1 = Crash2 hard hit w/RH
	Crash2_Soft_RH, // 39 D#1 = Crash2 (near Ride Cym) soft hit w/RH
	Crash1Choke, // 40 E1 = Crash1 Choke (hit w/RH, choke w/LH)
	Crash2Choke, // 41 F1 = Crash2 Choke (hit w/RH, choke w/LH)
	Ride_RH, // 42 F#1 = Ride Cym hit w/RH
	Ride_LH, // 43 (G1) is a ride hit w/LH
	Crash2_LH, // 44 (G#1) is a hit on crash 2 w/LH
	Crash2_Soft_LH, // 45 (A1) is a soft hit on crash 2 w/LH
	Tom1_LH, // 46 A#1 = Tom1 hit w/LH
	Tom1_RH, // 47 B1 = Tom1 hit w/RH
	Tom2_LH, // 48 C2 = Tom2 hit w/LH
	Tom2_RH, // 49 C#2 = Tom2 hit w/RH
	FloorTom_LH, // 50 D2 = Floor Tom hit w/LH
	FloorTom_RH // 51 D#2 = Floor Tom hit w/RH
}

struct Event
{
	this(string line, ref int lastTick)
	{
		import std.conv : to;
		import std.algorithm : splitter;
		import db.tools.tokeniser : Tokeniser;

		auto t = Tokeniser!(" \t", "``")(line);

		string delta = t.getFront();
		tick = lastTick + to!int(delta);
		lastTick = tick;

		string e = t.getFront();
		switch (e)
		{
			case "B":
				event = EventType.BPM;
				bpm.usPerBeat = cast(int)(to!double(t.getFront)*1000.0);
				break;
			case "A":
				event = EventType.Anchor;
				break;
			case "F":
				event = EventType.Freeze;
				freeze.usToFreeze = cast(int)(to!double(t.getFront)*1000.0);
				break;
			case "TS":
				event = EventType.TimeSignature;
				auto nd = splitter(t.getFront, '/');
				ts.numerator = to!int(nd.front); nd.popFront;
				ts.denominator = to!int(nd.front);
				break;
			case "N":
				event = EventType.Note;
				note.key = to!int(t.getFront);
				break;
			case "G":
				event = EventType.GuitarNote;
				auto n = splitter(t.getFront, ':');
				guitar._string = to!int(n.front); n.popFront;
				guitar.fret = to!int(n.front);
				break;
			case "L":
				event = EventType.Lyric;
				text = t.getFront[1..$-1];
				break;
			case "S":
				event = EventType.Special;
				special = cast(SpecialType)to!int(t.getFront);
				break;
			case "E":
				event = EventType.Event;
				text = t.getFront[1..$-1];
				break;
			case "SN":
				event = EventType.Section;
				text = t.getFront[1..$-1];
				break;
			case "DA":
				event = EventType.DrumAnimation;
				drumAnim = cast(DrumAnimation)(to!int(t.getFront));
				break;
			case "C":
				event = EventType.Chord;
				break;
			case "NP":
				event = EventType.NeckPosition;
				position = to!int(t.getFront);
				break;
			case "KP":
				event = EventType.KeyboardPosition;
				position = to!int(t.getFront);
				break;
			case "I":
				event = EventType.Lighting;
				text = t.getFront[1..$-1];
				break;
			case "DC":
				event = EventType.DirectedCut;
				text = t.getFront[1..$-1];
				break;
			case "M":
				event = EventType.MIDI;
				ubyte status = to!ubyte(t.getFront);
				if (status == 0xFF)
				{
					assert("todo!");
				}
				else if ((status & 0xF) == 0xF)
				{
					assert("todo!");
				}
				else
				{
					midi.type = status & 0xF0;
					midi.subType = status & 0xF;
					midi.channel = midi.subType;
					midi.note = to!int(t.getFront);
					midi.velocity = to!int(t.getFront);
				}
				break;
			default:
		}

		// optional flags and duration
		foreach (p; t)
		{
			if (p[0] == 'f')
				flags = to!uint(p[1..$]);
			else if (p[0] == 'l')
				duration = to!int(p[1..$]);
		}
	}

	string toString(int lastTick, string prefix = null, string suffix = null)
	{
		import std.format : format;

		static string fl(uint f)
		{
			if (f == 0)
				return null;
			return format(" f%x", f);
		}
		static string dur(int d)
		{
			if (d == 0)
				return null;
			return format(" l%d", d);
		}

		enum f = "%s%4d ";
		int tick = this.tick - lastTick;
		switch (event) with(EventType)
		{
			case BPM:
				return format(f~"B %g%s", prefix, tick, bpm.usPerBeat/1000.0, suffix);
			case Anchor:
				return format(f~"A %s", prefix, tick, suffix);
			case Freeze:
				return format(f~"F %g%s", prefix, tick, freeze.usToFreeze/1000.0, suffix);
			case TimeSignature:
				return format(f~"TS %d/%d%s", prefix, tick, ts.numerator, ts.denominator, suffix);
			case Note:
				return format(f~"N %d%s%s%s", prefix, tick, note.key, fl(flags), dur(duration), suffix);
			case GuitarNote:
				return format(f~"G %d:%d%s%s%s", prefix, tick, guitar._string, guitar.fret, fl(flags), dur(duration), suffix);
			case Lyric:
				return format(f~"L `%s`%s%s", prefix, tick, text, dur(duration), suffix);
			case Special:
				return format(f~"S %d%s%s", prefix, tick, special, dur(duration), suffix);
			case Event:
				return format(f~"E `%s`%s%s", prefix, tick, text, dur(duration), suffix);
			case Section:
				return format(f~"SN `%s`%s%s", prefix, tick, text, dur(duration), suffix);
			case DrumAnimation:
				return format(f~"DA %d%s%s", prefix, tick, drumAnim, dur(duration), suffix);
			case Chord:
				return format(f~"C %s", prefix, tick, suffix);
			case NeckPosition:
				return format(f~"NP %d%s", prefix, tick, position, suffix);
			case KeyboardPosition:
				return format(f~"KP %d%s", prefix, tick, position, suffix);
			case Lighting:
				return format(f~"I %s%s", prefix, tick, text, suffix);
			case DirectedCut:
				return format(f~"DC %s%s", prefix, tick, text, suffix);
			case MIDI:
				if (midi.type == 0xFF)
				{
					// we're missing the data for custom events!
					assert("todo!");
//					return format(f~"M %02x %02x ... %s", prefix, tick, midi.type, midi.subType, ..., suffix);
				}
				else if ((midi.type & 0xF) == 0xF)
				{
					// sysex messages should format the data into a hex string
					assert("todo!");
				}
				else
					return format(f~"M %02x %d %d%s%s", prefix, tick, midi.type|midi.subType, midi.note, midi.velocity, dur(duration), suffix);
				return null;
			default:
				return null;
		}
	}

	long time;		// the physical time of the note (in microseconds)

	int tick;		// in ticks
	int duration;	// note duration

	EventType event;
	uint flags;

	void* pScoreKeeperData;
	void* pPresentationData;

	struct BPM
	{
		int usPerBeat;
	}
	struct TimeSig
	{
		int numerator;
		int denominator;
	}
	struct Freeze
	{
		long usToFreeze;
	}
	struct Note
	{
		int key;
	}
	struct GuitarNote
	{
		int _string;
		int fret;
	}
	struct MIDI
	{
		ubyte type;
		ubyte subType;
		ubyte channel;
		int note;
		int velocity;
	}

	union
	{
		BPM bpm;
		Freeze freeze;
		TimeSig ts;
		Note note;
		GuitarNote guitar;
		SpecialType special;
		DrumAnimation drumAnim;
		string text;
		int chord;
		int position;
		MIDI midi;
	}
}


// Binary search on the events
// before: true = return event one before requested time, false = return event one after requested time
// type: "tick", "time" to search by tick or by time
private ptrdiff_t GetEventForOffset(bool before, bool byTime)(Event[] events, long offset)
{
	enum member = byTime ? "time" : "tick";

	if (events.empty)
		return -1;

	// get the top bit
	size_t i = events.length, topBit = 0;
	while ((i >>= 1))
		++topBit;
	i = topBit = 1 << topBit;

	// binary search bitchez!!
	ptrdiff_t target = -1;
	while (true)
	{
		if (i >= events.length) // if it's an invalid index
		{
			i = (i & ~topBit) | topBit>>1;
		}
		else if (mixin("events[i]." ~ member) == offset)
		{
			// return the first in sequence
			while (i > 0 && mixin("events[i-1]." ~ member) == mixin("events[i]." ~ member))
				--i;
			return i;
		}
		else if (mixin("events[i]." ~ member) > offset)
		{
			static if (!before)
				target = i;
			i = (i & ~topBit) | topBit>>1;
		}
		else
		{
			static if (before)
				target = i;
			i |= topBit>>1;
		}
		if (!topBit)
			break;
		topBit >>= 1;
	}

	return target;
}

private template AllIs(Ty, T...)
{
	static if (T.length == 0)
		enum AllIs = true;
	else
		enum AllIs = is(T[0] == Ty) && AllIs!(T[1..$], Ty);
}

// skip over events of specified types
ptrdiff_t SkipEvents(bool reverse = false, Types...)(Event[] events, ptrdiff_t e, Types types) if (AllIs!(E.EventType, Types))
{
outer: for (; (reverse && e >= 0) || (!reverse && e < events.length); e += reverse ? -1 : 1)
{
	foreach (t; types)
	{
		if (events[e].event == t)
			continue outer;
	}
	return e;
}
	return -1;
}

// skip events until we find one we're looking for
ptrdiff_t SkipToEvents(bool reverse = false, Types...)(Event[] events, ptrdiff_t e, Types types) if (AllIs!(EventType, Types))
{
	for (; (reverse && e >= 0) || (!reverse && e < events.length); e += reverse ? -1 : 1)
	{
		foreach (t; types)
		{
			if (events[e].event == t)
				return e;
		}
	}
	return -1;
}

// get all events at specified tick
Event[] EventsAt(Event[] events, int tick)
{
	ptrdiff_t i = events.GetEventForOffset!(false, false)(tick);
	if (i != tick)
		return null;
	auto e = i;
	while (e < events.length-1 && events[e+1].tick == events[e].tick)
		++e;
	return events[i..e+1];
}

ptrdiff_t FindEvent(Event[] events, EventType type, int tick, int key = -1)
{
	// find the events at the requested offset
	auto ev = events.EventsAt(tick);
	if (!ev)
		return -1;

	// match the other conditions
	foreach (ref e; ev)
	{
		if (!type || e.event == type)
		{
			if (key == -1 || e.note.key == key)
				return &e - events.ptr; // return it as an index (TODO: should this return a ref instead?)
		}
	}
	return -1;
}

private ptrdiff_t GetEvent(bool reverse, bool byTime, Types...)(Event[] events, long offset, Types types) if (AllIs!(EventType, Types))
{
	ptrdiff_t e = events.GetEventForOffset!(reverse, byTime)(offset);
	if (e < 0 || Types.length == 0)
		return e;
	return events.SkipToEvents!reverse(e, types);
}

ptrdiff_t GetNextEvent(Types...)(Event[] events, int tick, Types types) if (AllIs!(EventType, Types))
{
	return events.GetEvent!(false, false)(tick, types);
}

ptrdiff_t GetNextEventByTime(Types...)(Event[] events, long time, Types types) if (AllIs!(EventType, Types))
{
	return events.GetEvent!(false, true)(time, types);
}

ptrdiff_t GetMostRecentEvent(Types...)(Event[] events, int tick, Types types) if (AllIs!(EventType, Types))
{
	return events.GetEvent!(true, false)(tick, types);
}

ptrdiff_t GetMostRecentEventByTime(Types...)(Event[] events, long time, Types types) if (AllIs!(EventType, Types))
{
	return events.GetEvent!(true, true)(time, types);
}

Event[] Between(Event[] events, int startTick, int endTick)
{
	assert(endTick >= startTick, "endTick must be greater than startTick");
	size_t first = events.GetNextEvent(startTick);
	size_t last = events.GetNextEvent(endTick+1);
	if (first == -1)
		return events[$..$];
	else if (last == -1)
		return events[first..$];
	else
		return events[first..last];
}

Event[] BetweenTimes(Event[] events, long startTime, long endTime)
{
	assert(endTime >= startTime, "endTime must be greater than startTime");
	size_t first = events.GetNextEventByTime(startTime);
	size_t last = events.GetNextEventByTime(endTime+1);
	if (first == -1)
		return events[$..$];
	else if (last == -1)
		return events[first..$];
	else
		return events[first..last];
}
