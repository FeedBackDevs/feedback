module db.sequence;

import db.instrument;


enum Difficulty
{
	Easy,
	Medium,
	Hard,
	Expert,

	Count
}

enum EventType
{
	Note,
	Event,
	StarPower,
	FreeStyle,
	LeftPlayer,		// GH1/2 co-op mode
	RightPlayer		// GH1/2 co-op mode
}

struct Event
{
	EventType event;

	long time;		// the physical time of the note (in microseconds)
	int tick;		// in ticks

	int key;
	int param;		// for a note, this is the sustain
	string stringParam;
	uint flags;

	// temp runtime data
	int played;
}

class Sequence
{
	Instrument instrument;
	Difficulty difficulty;

	int difficultyMeter;	// from 1 - 10

	Event[] notes;

	// instrument specific parameters
	int numDoubleKicks; // keep a counter so we know if the drums have double kicks or not
}
