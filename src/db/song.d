module db.song;

import db.sequence;
import db.tools.midifile;

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

	this(MIDIFile midi)
	{
		//...
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

	// data...
	string songPath;

	string songName;
	string artistName;
	string year;
	string sourcePackageName;	// where did the song come from? (eg, "Rock Band II", "Guitar Hero Metallica", "Rush DLC", etc)
	string charterName;

	string cover;			// cover image
	string fretboard;		// custom fretboard graphic

	string tags;			// string tags for sorting/filtering
	string genre;
	string mediaType;		// media type for pfx theme purposes (cd/casette/vinyl/etc)

	string[string] params;	// optional key-value pairs (much data taken from the original .ini files, might be useful in future)

	// paths to music files (many of these may or may not be available for different songs)
	string songFilename;			// the backing track (often includes vocals)
	string songWithCrowdFilename;	// backing track with crowd sing-along (sing-along, for star-power mode/etc.)
	string vocals;					// discreet vocal track
	string crowd;					// crowd-sing-along, for star-power/etc.
	string guitarFilename;
	string rhythmFilename;
	string bassFilename;
	string keysFilename;
	string drumsFilename;			// drums mixed to a single track

	// paths to music for split drums (guitar hero world tour songs split the drums into separate tracks)
	string kickFilename;
	string snareFilename;
	string cymbalsFilename;	// all cymbals
	string tomsFilename;	// all toms

	// multitrack support? (Rock Band uses .mogg files; multitrack ogg files)
//	string multitrackFilename;		// multitrack filename (TODO: this will take some work...)
//	Instrument[] trackAssignment;	// assignment of each track to parts

	// song data
	long startOffset;		// starting offset, in microseconds

	int resolution;

	SyncEvent[] sync;		// song sync stuff
	SongEvent[] events;		// general song events (effects, lighting, etc?)
	Sequence[Difficulty.Count*Part.Count] tracks;

	MFMaterial *pFretboard;

	MFAudioStream *pSong;
	MFAudioStream *pSongWithCrowd;
	MFAudioStream *pVocals;
	MFAudioStream *pCrowd;
	MFAudioStream *pGuitar;
	MFAudioStream *pRhythm;
	MFAudioStream *pBass;
	MFAudioStream *pKeys;
	MFAudioStream *pDrums;
	MFAudioStream *pKick;
	MFAudioStream *pSnare;
	MFAudioStream *pCymbals;
	MFAudioStream *pToms;
}
