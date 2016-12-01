module db.library.song;

public import db.chart : Chart;

import fuji.material;
import fuji.sound;

import luad.base : noscript;

import std.string : toStringz;


// music files (many of these may or may not be available for different songs)
enum Streams
{
	Song,			// the backing track (often includes vocals)
	SongWithCrowd,	// backing track with crowd sing-along (sing-along, for star-power mode/etc.)
	Vocals,			// discreet vocal track
	Crowd,			// crowd-sing-along, for star-power/etc.
	Guitar,
	Rhythm,
	Bass,
	Keys,
	Drums,			// drums mixed to a single track

	// paths to music for split drums (guitar hero world tour songs split the drums into separate tracks)
	Kick,
	Snare,
	Cymbals,		// all cymbals
	Toms,			// all toms

	Count
}


class Song
{
	this(string id)
	{
		_id = id;
	}

	@property Chart chart()
	{
		if (!_chart)
			_chart = new Chart(localChart);

		return _chart;
	}

	@property string preview() { return _preview; }
	@property string cover() { return coverImage; }

	@property string path() { return chart.songPath; }

	@property string id() { return _id; }
	@property string name() { return chart.name; }
	@property string variant() { return chart.variant; }
	@property string subtitle() { return chart.subtitle; }
	@property string artist() { return chart.artist; }
	@property string album() { return chart.album; }
	@property string year() { return chart.year; }
	@property string packageName() { return chart.packageName; }
	@property string charterName() { return chart.charterName; }

	// TODO: tags should be split into an array
	//	@property string tags() { return song.tags; }
	@property string genre() { return chart.genre; }
	@property string mediaType() { return chart.mediaType; }

	// TODO: is AA
	//	@property string params() { return song.params; }

	@property int resolution() { return chart.resolution; }
	@property long startOffset() { return chart.startOffset; }


	// TODO: add something to fetch information about the streams...

	void pause(bool bPause)
	{
		foreach (s; streams)
			if (s)
				MFSound_PauseStream(s, bPause);
	}

	void seek(double offsetInSeconds)
	{
		foreach (s; streams)
			if (s)
				MFSound_SeekStream(s, offsetInSeconds);
	}

	void setVolume(string part, float volume)
	{
		// TODO: figure how parts map to playing streams
	}

	void setPan(string part, float pan)
	{
		// TODO: figure how parts map to playing streams
	}

@noscript:
	struct Source
	{
		struct File
		{
			Streams type;
			string stream;
		}

		File[] streams;

		void addStream(string filename, Streams type = Streams.Song) { streams ~= File(type, filename); }
	}

	string _id;

	// TODO: link to archive entry if the chart comes from the archive...
	//	ArchiveEntry archiveEntry;		// reference to the archive entry, if the song is present in the archive...

	string localChart;				// path to local chart file

	// associated data
	string _preview;				// short preview clip
	string video;					// background video

	string coverImage;				// cover image
	string background;				// background image
	string fretboard;				// custom fretboard graphic

	// audio sources
	Source[] sources;

	// runtime data
	Chart _chart;

	MFAudioStream*[Streams.Count] streams;
	MFVoice*[Streams.Count] voices;

	Material _cover;
	Material _background;
	Material _fretboard;

	// methods...
	~this()
	{
		release();
	}

	Source* addSource()
	{
		sources ~= Source();
		return &sources[$-1];
	}

	void prepare()
	{
		chart.prepare();

		// load audio streams...

		// load song data...

		// TODO: choose a source
		Source* source = &sources[0];

		// prepare the music streams
		foreach (ref s; source.streams)
		{
			streams[s.type] = MFSound_CreateStream(s.stream.toStringz, MFAudioStreamFlags.QueryLength | MFAudioStreamFlags.AllowSeeking);
			if (!streams[s.type])
				continue;

			MFSound_PlayStream(streams[s.type], MFPlayFlags.BeginPaused);

			voices[s.type] = MFSound_GetStreamVoice(streams[s.type]);
			//			MFSound_SetPlaybackRate(voices[i], 1.0f); // TODO: we can use this to speed/slow the song...
		}

		// load data...
		if (coverImage)
			_cover = Material(coverImage);
		if (background)
			_background = Material(background);
		if (fretboard)
			_fretboard = Material(fretboard);
	}

	void release()
	{
		foreach (ref s; streams)
		{
			if (s)
			{
				MFSound_DestroyStream(s);
				s = null;
			}
		}

		_cover = null;
		_background = null;
		_fretboard = null;
	}
}
