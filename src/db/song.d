module db.song;

import db.instrument;
import db.sequence;

import fuji.material;
import fuji.sound;


enum SyncEventType
{
	BPM,
	Anchor,
	TimeSignature
}

enum SongEventType
{
	Event,
}

struct SyncEvent
{
	SyncEventType event;

	long time;		// the real-time of the note (in microseconds)
	int tick;		// in ticks
	int bpm;		// in thousandths of a beat per minute
}

struct SongEvent
{
	EventType event;

	long time;		// the physical time of the note (in microseconds)
	int tick;		// in ticks

	string stringParam;
}

class Song
{
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
	SongEvent[] events;	// general song events (effects, lighting, etc?)
	Sequence[Difficulty.Count*Instrument.Count] tracks;

	MFAudioStream *pStream;
	MFAudioStream *pGuitar;
	MFAudioStream *pBass;

	MFMaterial *pFretboard;
}
