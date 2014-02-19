module db.sequence;

import db.instrument;


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
