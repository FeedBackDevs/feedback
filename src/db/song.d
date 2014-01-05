module db.song;

import db.instrument;

import fuji.material;
import fuji.sound;

enum Difficulty
{
	Easy,
	Medium,
	Hard,
	Expert,

	Count
}

enum GuitarNotes
{
	Green,
	Red,
	Yellow,
	Blue,
	Orange,
	Open
}

enum GuitarNoteFlags
{
	HOPO,	// hammer-on/pull-off
	Tap,	// tap note
	Solo,	// rock band solo keys
	Slide	// guitar hero slider
}

enum DrumNotes
{				// RB kit		GH kit
	Snare,		//   R			  R
	Tom1,		//   Y			  B
	Tom2,		//   B			  B/G?
	Tom3,		//   G			  G
	Hat,		//   Y			  Y
	Spash,		//   B			  Y/O?
	Crash,		//   B/G?		  Y/O?
	Ride,		//   G			  O
	Kick,
}

enum DrumNoteFlags
{
	DoubleKick,	// double kick notes are hidden in single-kick mode
	OpenHat		// interesting if drum kit has a hat pedal
}

enum DanceNotes
{
	Left,
	Up,
	Down,
	Right,
	UpLeft,
	UpRight,
	Left2,
	Up2,
	Down2,
	Right2,
	UpLeft2,
	UpRight2
}

enum SyncEventType
{
	BPM,
	Anchor,
	TimeSignature
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

struct SyncEvent
{
	SyncEventType event;

	long time;		// the real-time of the note (in microseconds)
	int tick;		// in ticks
	int bpm;		// in thousandths of a beat per minute
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

class Song
{
	struct Track
	{
		int difficulty;
		int numDoubleKicks; // keep a counter so we know if the drums have double kicks or not

		Event[] notes;
	}

	this(string filename = null)
	{
	}

	~this()
	{
	}

	void SaveChart()
	{
	}

	void Play(long time)
	{
	}

	void Stop()
	{
	}

	void SetVolume(float volume)
	{
	}

	void SetPan(float pan)
	{
	}

	int GetLastNoteTick()
	{
		return 0;
	}

	int GetStartBPM()
	{
		return 0;
	}

	void CalculateNoteTimes(int stream, int startTick)
	{
	}

	long CalculateTimeOfTick(int tick)
	{
		return 0;
	}

	int CalculateTickAtTime(long time, int *pBPM = null)
	{
		return 0;
	}

	string songName;
	string artistName;
	string charterName;
	string songPath;

	string musicFilename;
	string guitarFilename;
	string bassFilename;

	string cover;		// cover image
	string fretboard;	// custom fretboard graphic

	string tags;		// string tags for sorting/filtering
	string genre;
	string mediaType;	// media type for pfx theme purposes (cd/casette/vinyl/etc)

	long startOffset;	// starting offset, in microseconds

	int resolution;

	SyncEvent[] sync;	// song sync stuff
	Event[] events;		// general song events, specials, etc
	Track[Difficulty.Count*Instrument.Count] tracks;

	MFAudioStream *pStream;
	MFAudioStream *pGuitar;
	MFAudioStream *pBass;

	MFMaterial *pFretboard;
}
