module db.sequence;

import db.instrument;

import std.string;

enum Part
{
	Unknown,		// if the instrument type is unknown, or has not been assigned

	LeadGuitar,		// lead guiutar
	RhythmGuitar,	// rhythm guitar
	Bass,			// bass guitar
	Drums,			// drums
	Vox,			// lead vocals
	Keys,			// keyboard
	ProGuitar,		// pro guitar
	ProRhythmGuitar,// pro rhythm guitar
	ProBass,		// pro bass
	ProKeys,		// pro keyboard
	DJ,				// DJ hero

	// Bemani games
	Dance,			// dance mat
	Beatmania,		// beatmania controller

	// Silly (fun!) shit
	Conga,			// ie, Donkey Conga
	Taiko,			// http://www.screwattack.com/sites/default/files/image/images/News/2012/0402/261_560635649740_23911393_36125747_3873_n.jpg

	Count
}

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

struct Event
{
	this(string text)
	{
		// string...
	}

	string toString(int lastTick, string prefix = null, string suffix = null)
	{
		static string flags(uint f)
		{
			if(!f)
				return null;
			return format(" f%x", f);
		}
		static string dur(int d)
		{
			if(!d)
				return null;
			return format(" l%d", d);
		}

		enum f = "%s%4d ";
		int tick = this.tick - lastTick;
		switch(event) with(EventType)
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
				return format(f~"N %d%s%s%s", prefix, tick, note.key, flags(note.flags), dur(duration), suffix);
			case GuitarNote:
				return format(f~"G %d:%d%s%s%s", prefix, tick, guitar._string, guitar.fret, flags(note.flags), dur(duration), suffix);
			case Lyric:
				return format(f~"L `%s`%s%s", prefix, tick, text, dur(duration), suffix);
			case Special:
				return format(f~"S %d%s%s", prefix, tick, special, dur(duration), suffix);
			case Event:
				return format(f~"E `%s`%s%s", prefix, tick, text, dur(duration), suffix);
			case Section:
				return format(f~"S `%s`%s%s", prefix, tick, text, dur(duration), suffix);
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
				if(midi.type == 0xFF)
				{
					// we're missing the data for custom events!
					assert("todo!");
//					return format(f~"M %02x %02x ... %s", prefix, tick, midi.type, midi.subType, ..., suffix);
				}
				else if((midi.type & 0xF) == 0xF)
				{
					// sysex messages should format the data into a hex string
					assert("todo!");
				}
				else
					return format(f~"M %02x %d %d%s%s", prefix, tick, midi.type|midi.subType, midi.note, midi.velocity, dur(duration), suffix);
			default:
				return null;
		}
	}

	long time;		// the physical time of the note (in microseconds)

	int tick;		// in ticks
	int duration;	// note duration

	EventType event;

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
		uint flags;
	}
	struct GuitarNote
	{
		int _string;
		uint flags;
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

class Sequence
{
	Part part;

	string variation;
	string difficulty;
	int difficultyMeter;	// from 1 - 10

	Event[] notes;

	// instrument specific parameters
	int numDoubleKicks; // keep a counter so we know if the drums have double kicks or not
}

immutable InstrumentType[Part.Count] instrumentForPart =
[
	InstrumentType.Unknown,				// Unknown
	InstrumentType.GuitarController,	// LeadGuitar
	InstrumentType.GuitarController,	// RhythmGuitar
	InstrumentType.GuitarController,	// Bass
	InstrumentType.Drums,				// Drums
	InstrumentType.Vocals,				// Vox
	InstrumentType.Keyboard,			// Keys
	InstrumentType.Guitar,				// ProGuitar
	InstrumentType.Guitar,				// ProRhythmGuitar
	InstrumentType.Bass,				// ProBass
	InstrumentType.Keyboard,			// ProKeys
	InstrumentType.DJ,					// DJ
	InstrumentType.Dance,				// Dance
	InstrumentType.Beatmania,			// Beatmania
	InstrumentType.Conga,				// Conga
	InstrumentType.Taiko				// Taiko
];


template instrumentFor(Part part)		{ enum instrumentOf = instrumentForPart[part]; }
