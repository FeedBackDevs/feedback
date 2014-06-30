module db.tools.guitarprofile;

import fuji.fuji;
import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import std.string;
import std.range;
import std.exception;

import db.tools.range;

class GuitarProFile
{
	this(const(char)[] filename)
	{
		ubyte[] file = enforce(MFFileSystem_Load(filename), "Couldn't load file!");
		scope(exit) MFHeap_Free(file); // this should happen whether or not the base constructor throws
		this(file);
	}

	this(const(ubyte)[] buffer)
	{
		readSignature(buffer);
		readSongAttributes(buffer);
		readTrackDefaults(buffer);

		int numBars = buffer.getFrontAs!int();           // Number of bars
		assert(numBars > 0 && numBars < 16384, "Insane number of bars");
		measures = new MeasureInfo[numBars];

		int numTracks = buffer.getFrontAs!int();         // Number of tracks
		assert(numTracks > 0 && numTracks <= 32, "Insane number of tracks");
		tracks = new Track[numTracks];

		readBarProperties(buffer);
		readTrackProperties(buffer);

		readTabs(buffer);

		if(!buffer.empty)
		{
			int ex = buffer.getFrontAs!int();            // Exit code: 00 00 00 00
//			if(ex != 0)
//				kdWarning() << "File not ended with 00 00 00 00\n";
//			if (!buffer.empty)
//				kdWarning() << "File not ended - there's more data!\n";
		}
	}

	enum
	{
		TRACK_MAX_NUMBER = 32,
		LYRIC_LINES_MAX_NUMBER = 5,
		STRING_MAX_NUMBER = 7
	};

	enum Flags
	{
		ARC = 1,
		Dot = 2,
		PalmMute = 4,
		Triplet = 8
	}

	enum Effect
	{
		Harmonic = 1,
		ArtHarm = 2,
		Legato = 3,
		Slide = 4,
		LetRing = 5,
		StopRing = 6
	}

	struct MidiTrack
	{
		int patch;
		ubyte volume;
		ubyte pan;
		ubyte chorus;
		ubyte reverb;
		ubyte phase;
		ubyte tremolo;
	}

	struct MeasureInfo
	{
		enum Bits
		{
			TSNumerator,
			TSDenimonator,
			BeginRepeat,
			NumRepeats,
			AlternativeEnding,
			NewSection,
			NewKeySignature,
			DoubleBar
		}

		ubyte bitmask;

		ubyte tn = 4;
		ubyte td = 4;
		ubyte numRepeats;
		ubyte altEnding;
		ubyte keysig;
		ubyte minor;

		string section;
		int colour;

		bool has(Bits bit) { return (bitmask & MFBit(bit)) != 0; }
	}

	struct Beat
	{
		ubyte bitmask;

		ubyte pauseKind;

		byte length; // quarter_note / 2^length
		byte[STRING_MAX_NUMBER] frets = -1;
		byte[STRING_MAX_NUMBER] effects;
		ubyte flags;

		int tuple;

		string text;

		// mixer variations
		int tempo;
		ubyte patch;

		ubyte volume;
		ubyte volumeTrans;
		ubyte pan;
		ubyte panTrans;
		ubyte chorus;
		ubyte chorusTrans;
		ubyte reverb;
		ubyte reverbTrans;
		ubyte phase;
		ubyte phaseTrans;
		ubyte tremolo;
		ubyte tremoloTrans;
		ubyte tempoTrans;
	}

	struct Measure
	{
		MeasureInfo *pInfo;
		uint beat, numBeats;
	}

	struct Track
	{
		enum Bits
		{
			Drums,
			TwelveString,
			Banjo
		}

		struct String
		{
			int tune;
		}

		ubyte bitmask;

		string name;

		String strings[];

		int midiPort;
		int channel;
		int channel2;

		int frets;
		int capo;
		int colour;

		int patch;

		Measure[] measures;
		Beat[] beats;

		bool isSet(Bits bit) const pure nothrow { return (bitmask & MFBit(bit)) != 0; }
		@property int numStrings() const pure nothrow { return cast(int)strings.length; }
	}

	int versionMajor;
	int versionMinor;

	string title;
	string subtitle;
	string artist;
	string album;
	string composer;
	string copyright;
	string transcriber;
	string instructions;
	string commments;

	ubyte shuffleFeel;

	int tempo;
	int key;
	int octave;

	MidiTrack[16][4] midiTracks;

	MeasureInfo[] measures;
	Track[] tracks;



private:

	void readSignature(ref const(ubyte)[] buffer)
	{
		const(char)[] s = buffer.readPascalString(30);

		// Parse version string
		switch(s)
		{
			case "FICHIER GUITARE PRO v1":		versionMajor = 1; versionMinor = 0; break;
			case "FICHIER GUITARE PRO v1.01":	versionMajor = 1; versionMinor = 1; break;
			case "FICHIER GUITARE PRO v1.02":	versionMajor = 1; versionMinor = 2; break;
			case "FICHIER GUITARE PRO v1.03":	versionMajor = 1; versionMinor = 3; break;
			case "FICHIER GUITARE PRO v1.04":	versionMajor = 1; versionMinor = 4; break;
			case "FICHIER GUITAR PRO v2.20":	versionMajor = 2; versionMinor = 20; break;
			case "FICHIER GUITAR PRO v2.21":	versionMajor = 2; versionMinor = 21; break;
			case "FICHIER GUITAR PRO v3.00":	versionMajor = 3; versionMinor = 0; break;
			case "FICHIER GUITAR PRO v4.00":	versionMajor = 4; versionMinor = 0; break;
			case "FICHIER GUITAR PRO v4.06":	versionMajor = 4; versionMinor = 6; break;
			case "FICHIER GUITAR PRO L4.06":	versionMajor = 4; versionMinor = 6; break;
			default:
				assert(false, "Invalid file format: " ~ s);
		}
	}

	void readSongAttributes(ref const(ubyte)[] buffer)
	{
		title = buffer.readDelphiString().idup;
		subtitle = buffer.readDelphiString().idup;
		artist = buffer.readDelphiString().idup;
		album = buffer.readDelphiString().idup;
		composer = buffer.readDelphiString().idup;
		copyright = buffer.readDelphiString().idup;
		transcriber = buffer.readDelphiString().idup;
		instructions = buffer.readDelphiString().idup;


		// Notice lines
		int n = buffer.getFrontAs!int();
		foreach(i; 0..n)
		{
			auto line = buffer.readDelphiString();
			commments ~= i > 0 ? "\n" ~ line : line;
		}

		shuffleFeel = buffer.getFront();

		if(versionMajor >= 4)
		{
			// Lyrics
			int lyricTrack = buffer.getFrontAs!int();              // GREYFIX: Lyric track number start

			for(int i = 0; i < LYRIC_LINES_MAX_NUMBER; i++)
			{
				int bar = buffer.getFrontAs!int();                 // GREYFIX: Start from bar
				auto lyric = buffer.readWordPascalString();      // GREYFIX: Lyric line
			}
		}

		tempo = buffer.getFrontAs!int();       // Tempo

		if(versionMajor >= 4)
		{
			key = buffer.getFront();         // GREYFIX: key
			octave = buffer.getFrontAs!int();  // GREYFIX: octave
		}
		else
		{
			key = buffer.getFrontAs!int();     // GREYFIX: key
		}
	}

	void readTrackDefaults(ref const(ubyte)[] buffer)
	{
		foreach(i; 0 .. 16 * 4)
		{
			MidiTrack *pTrack = &midiTracks[i&3][i>>2];

			pTrack.patch = buffer.getFrontAs!int(); // MIDI Patch
			pTrack.volume = buffer.getFront();      // GREYFIX: volume
			pTrack.pan = buffer.getFront();         // GREYFIX: pan
			pTrack.chorus = buffer.getFront();      // GREYFIX: chorus
			pTrack.reverb = buffer.getFront();      // GREYFIX: reverb
			pTrack.phase = buffer.getFront();       // GREYFIX: phase
			pTrack.tremolo = buffer.getFront();     // GREYFIX: tremolo

			// 2 bytes of padding (should be 0)
			ubyte num = buffer.getFront(); assert(num == 0, "Expected: zero byte");
			num = buffer.getFront(); assert(num == 0, "Expected: zero byte");
		}
	}

	void readBarProperties(ref const(ubyte)[] buffer)
	{
		ubyte tn = 4, td = 4, ks, min;
		foreach(i, ref m; measures)
		{
			m.bitmask = buffer.getFront();

			// GREYFIX: new_time_numerator
			if(m.has(MeasureInfo.Bits.TSNumerator))
				tn = buffer.getFront();
			// GREYFIX: new_time_denominator
			if(m.has(MeasureInfo.Bits.TSDenimonator))
				td = buffer.getFront();
			// GREYFIX: number_of_repeats
			if(m.has(MeasureInfo.Bits.NumRepeats))
				m.numRepeats = buffer.getFront();
			// GREYFIX: alternative_ending_to
			if(m.has(MeasureInfo.Bits.AlternativeEnding))
				m.altEnding = buffer.getFront();
			// GREYFIX: new section
			if(m.has(MeasureInfo.Bits.NewSection))
			{
				m.section = buffer.readDelphiString().idup;
				m.colour = buffer.getFrontAs!int(); // color?
			}
			if(m.has(MeasureInfo.Bits.NewKeySignature))
			{
				ks = buffer.getFront();		// GREYFIX: alterations_number
				min = buffer.getFront();		// GREYFIX: minor
			}

			m.tn = tn;
			m.td = td;
			m.keysig = ks;
			m.minor = min;
		}
	}

	void readTrackProperties(ref const(ubyte)[] buffer)
	{
		foreach(i, ref t; tracks)
		{
			t.bitmask = buffer.getFront();	// GREYFIX: simulations bitmask

			t.name = buffer.readPascalString(40).idup;    // Track name

			// Tuning information
			int numStrings = buffer.getFrontAs!int();
			assert(numStrings > 0 && numStrings <= STRING_MAX_NUMBER, "Insane number of strings");
			t.strings = new Track.String[numStrings];

			// Parse [0..string-1] with real string tune data in reverse order
			for(ptrdiff_t j = t.numStrings-1; j >= 0; --j)
			{
				t.strings[j].tune = buffer.getFrontAs!int();
				assert(t.strings[j].tune < 128, "Insane tuning");
			}

			// Throw out the other useless garbage in [string..MAX-1] range
			for(size_t j = t.numStrings; j < STRING_MAX_NUMBER; j++)
				buffer.getFrontAs!int();

			// GREYFIX: auto flag here?

			t.midiPort = buffer.getFrontAs!int();	// GREYFIX: MIDI port
			t.channel = buffer.getFrontAs!int();	// MIDI channel 1
			t.channel2 = buffer.getFrontAs!int();	// GREYFIX: MIDI channel 2
			t.frets = buffer.getFrontAs!int();		// Frets
			t.capo = buffer.getFrontAs!int();		// GREYFIX: Capo
			t.colour = buffer.getFrontAs!int();		// GREYFIX: Color

			assert(t.frets > 0 && t.frets <= 100, "Insane number of frets");
			assert(t.channel <= 16, "Insane MIDI channel 1");
			assert(t.channel2 >= 0 && t.channel2 <= 16, "Insane MIDI channel 2");

			// Fill remembered values from defaults
			t.patch = midiTracks[0][i].patch;
		}
	}

	void readTabs(ref const(ubyte)[] buffer)
	{
		foreach(ref t; tracks)
			t.measures = new Measure[measures.length];

		foreach(i, ref mi; measures)
		{
			foreach(ref t; tracks)
			{
				Measure* m = &t.measures[i];
				m.pInfo = &mi;

				int numBeats = buffer.getFrontAs!int();
				assert(numBeats >= 0 && numBeats <= 128, "insane number of beats");

				m.beat = cast(uint)t.beats.length;
				m.numBeats = numBeats;

				foreach(_; 0..numBeats)
				{
					Beat b;

					b.bitmask = buffer.getFront();

					if(b.bitmask & 0x01)     // dotted column
						b.flags |= MFBit!(Flags.Dot);

					if(b.bitmask & 0x40)
						b.pauseKind = buffer.getFront(); // GREYFIX: pause_kind

					// Guitar Pro 4 beat lengths are as following:
					// -2 = 1    => 480     3-l = 5  2^(3-l)*15
					// -1 = 1/2  => 240           4
					//  0 = 1/4  => 120           3
					//  1 = 1/8  => 60            2
					//  2 = 1/16 => 30 ... etc    1
					//  3 = 1/32 => 15            0
					b.length = buffer.getFront();

					if(b.bitmask & 0x20)
					{
						b.tuple = buffer.getFrontAs!int();
						assert(b.tuple >= 3 && b.tuple <= 13, "Invalid tuple?");
					}

					if(b.bitmask & 0x02)     // Chord diagram
					{
//						readChord();
						int x = 0;
					}

					if(b.bitmask & 0x04)
						b.text = buffer.readDelphiString().idup;

					// GREYFIX: column-wide effects
					if(b.bitmask & 0x08)
						readColumnEffects(buffer, b, t);

					if(b.bitmask & 0x10)     // mixer variations
					{
						b.patch = buffer.getFront();   // GREYFIX: new MIDI patch
						b.volume = buffer.getFront();  // GREYFIX: new
						b.pan = buffer.getFront();     // GREYFIX: new
						b.chorus = buffer.getFront();  // GREYFIX: new
						b.reverb = buffer.getFront();  // GREYFIX: new
						b.phase = buffer.getFront();   // GREYFIX: new
						b.tremolo = buffer.getFront(); // GREYFIX: new
						b.tempo = buffer.getFrontAs!int();    // GREYFIX: new tempo

						// GREYFIX: transitions
						if(b.volume != -1)   b.volumeTrans = buffer.getFront();
						if(b.pan != -1)      b.panTrans = buffer.getFront();
						if(b.chorus != -1)   b.chorusTrans = buffer.getFront();
						if(b.reverb != -1)   b.reverbTrans = buffer.getFront();
						if(b.phase != -1)    b.phaseTrans = buffer.getFront();
						if(b.tremolo != -1)  b.tremoloTrans = buffer.getFront();
						if(b.tempo != -1)    b.tempoTrans = buffer.getFront();

						if(versionMajor >= 4)
							buffer.getFront();  // bitmask: what should be applied to all tracks
					}

					int strings = buffer.getFront();  // used strings mask
					for(int s = STRING_MAX_NUMBER - 1; s >= 0; --s)
					{
						if((strings & (1 << s)) != 0 && (STRING_MAX_NUMBER - 1 - s) < t.numStrings)
							readNote(buffer, b, t, s);
					}

					t.beats ~= b;
				}
			}
		}
	}

	void readNote(ref const(ubyte)[] buffer, ref Beat b, ref Track t, int s)
	{
		ubyte note_bitmask = buffer.getFront();

		if(note_bitmask & 0x20) // GREYFIX: note type
		{
			ubyte type = buffer.getFront();

			if(type == 2)                      // link with previous beat
			{
				b.flags |= Flags.ARC;
				b.effects[s] = 0;//Effect.DeadNote;
			}
			else if(type == 3)                      // dead notes
				b.frets[s] = -2;
		}

		if(note_bitmask & 0x01) // GREYFIX: note != beat
		{
			ubyte length = buffer.getFront();
			ubyte tuple = buffer.getFront();
		}

		if(note_bitmask & 0x02) // GREYFIX: note is dotted
		{}

		if(note_bitmask & 0x10) // GREYFIX: velocity
		{
			ubyte velocity = buffer.getFront();
		}

		if(note_bitmask & 0x20)
		{
			b.frets[s] = buffer.getFront();
		}

		if(note_bitmask & 0x80)               // GREYFIX: fingering
		{
			buffer.getFront();
			buffer.getFront();
		}

		if(note_bitmask & 0x08)
		{
			ubyte mod_mask1 = buffer.getFront();
			ubyte mod_mask2 = versionMajor >= 4 ? buffer.getFront() : 0;

			if(mod_mask1 & 0x01)
			{
				readChromaticGraph(buffer);      // GREYFIX: bend graph
			}
			if (mod_mask1 & 0x02)                // hammer on / pull off
				b.effects[s] |= Effect.Legato;
			if (mod_mask1 & 0x08)                // let ring
				b.effects[s] |= Effect.LetRing;
			if (mod_mask1 & 0x10)                // GREYFIX: graces
			{
				buffer.getFront();               // GREYFIX: grace fret
				buffer.getFront();               // GREYFIX: grace dynamic
				buffer.getFront();               // GREYFIX: grace transition
				buffer.getFront();               // GREYFIX: grace length
			}
			if(versionMajor >= 4)
			{
				if(mod_mask2 & 0x01)                // staccato - we do palm mute
					b.flags |= Flags.PalmMute;
				if(mod_mask2 & 0x02)                // palm mute - we mute the whole column
					b.flags |= Flags.PalmMute;
				if(mod_mask2 & 0x04)                // GREYFIX: tremolo
				{
					buffer.getFront();              // GREYFIX: tremolo picking length
				}
				if(mod_mask2 & 0x08)                // slide
				{
					b.effects[s] |= Effect.Slide;
					buffer.getFront();              // GREYFIX: slide kind
				}
				if(mod_mask2 & 0x10)                // GREYFIX: harmonic
				{
					buffer.getFront();              // GREYFIX: harmonic kind
				}
				if(mod_mask2 & 0x20)                // GREYFIX: trill
				{
					buffer.getFront();              // GREYFIX: trill fret
					buffer.getFront();              // GREYFIX: trill length
				}
			}
		}
	}

	void readChromaticGraph(ref const(ubyte)[] buffer)
	{
		// GREYFIX: currently just skips over chromatic graph
		buffer.getFront();                    // icon
		buffer.getFrontAs!int();              // shown amplitude
		int n = buffer.getFrontAs!int();      // number of points
		foreach(i; 0..n)
		{
			buffer.getFrontAs!int();          // time
			buffer.getFrontAs!int();          // pitch
			buffer.getFront();                // vibrato
		}
	}

	void readColumnEffects(ref const(ubyte)[] buffer, ref Beat b, ref Track t)
	{
		ubyte fx_bitmask1 = buffer.getFront();
		ubyte fx_bitmask2 = versionMajor >= 4 ? buffer.getFront() : 0;

		if(fx_bitmask1 & 0x20)      // GREYFIX: string torture
		{
			ubyte effect = buffer.getFront();
			switch (effect)
			{
				case 0:                    // GREYFIX: tremolo bar
					if(versionMajor < 4)
						buffer.getFrontAs!int();
					break;
				case 1:                    // GREYFIX: tapping
					if(versionMajor < 4)
						buffer.getFrontAs!int(); // ?
					break;
				case 2:                    // GREYFIX: slapping
					if(versionMajor < 4)
						buffer.getFrontAs!int(); // ?
					break;
				case 3:                    // GREYFIX: popping
					if(versionMajor < 4)
						buffer.getFrontAs!int(); // ?
					break;
				default:
					assert(false, "Unknown string torture effect");
			}
		}
		if(fx_bitmask1 & 0x04)      // GP3 column-wide natural harmonic
		{
			foreach(i; 0 .. t.numStrings)
				b.effects[i] |= Effect.Harmonic;
		}
		if(fx_bitmask1 & 0x08)      // GP3 column-wide artificial harmonic
		{
			foreach(i; 0 .. t.numStrings)
				b.effects[i] |= Effect.ArtHarm;
		}
		if(fx_bitmask2 & 0x04)
			readChromaticGraph(buffer);   // GREYFIX: tremolo graph
		if(fx_bitmask1 & 0x40)
		{
			buffer.getFront();      // GREYFIX: down stroke length
			buffer.getFront();      // GREYFIX: up stroke length
		}
		if(fx_bitmask2 & 0x02)
		{
			buffer.getFront();      // GREYFIX: stroke pick direction
		}
		if(fx_bitmask1 & 0x01)      // GREYFIX: GP3 column-wide vibrato
		{
		}
		if(fx_bitmask1 & 0x02)      // GREYFIX: GP3 column-wide wide vibrato (="tremolo" in GP3)
		{
		}
	}




}


private:

const(char)[] readPascalString(ref inout(ubyte)[] buffer, int maxlen)
{
	ubyte l = buffer.getFront();
	auto s = buffer.getFrontN(l);
	buffer.getFrontN(maxlen - l);
	return cast(const(char)[])s;
}

const(char)[] readWordPascalString(ref inout(ubyte)[] buffer)
{
	int l = buffer.getFrontAs!int();
	auto s = buffer.getFrontN(l);
	return cast(const(char)[])s;
}

const(char)[] readDelphiString(ref inout(ubyte)[] buffer)
{
	int maxl = buffer.getFrontAs!int();
	MFEndian_LittleToHost(&maxl);

	ubyte l = buffer.getFront();
	assert(maxl == l + 1, "first word doesn't match second byte");

	return cast(const(char)[])buffer.getFrontN(l);
}

/+
#include "convertgtp.h"

#include <klocale.h>
#include <qfile.h>
#include <qdatastream.h>

ConvertGtp::ConvertGtp(TabSong *song): ConvertBase(song)
{
	strongChecks = TRUE;
}

void ConvertGtp::readChord()
{
	int x1, x2, x3, x4;
	Q_UINT8 num;
	QString text;
	char garbage[50];
	// GREYFIX: currently just skips over chord diagram

	// GREYFIX: chord diagram
	x1 = getFrontAs!int();
	if (x1 != 257)
		kdWarning() << "Chord INT1=" << x1 << ", not 257\n";
	x2 = getFrontAs!int();
	if (x2 != 0)
		kdWarning() << "Chord INT2=" << x2 << ", not 0\n";
	x3 = getFrontAs!int();
	kdDebug() << "Chord INT3: " << x3 << "\n"; // FF FF FF FF if there is diagram
	x4 = getFrontAs!int();
	if (x4 != 0)
		kdWarning() << "Chord INT4=" << x4 << ", not 0\n";
	(*stream) >> num;
	if (num != 0)
		kdWarning() << "Chord BYTE5=" << (int) num << ", not 0\n";
	text = readPascalString(25);
	kdDebug() << "Chord diagram: " << text << "\n";

	// Chord diagram parameters - for every string
	for (int i = 0; i < STRING_MAX_NUMBER; i++) {
		x1 = getFrontAs!int();
		kdDebug() << x1 << "\n";
	}

	// Unknown bytes
	stream->readRawBytes(garbage, 36);

	kdDebug() << "after chord, position: " << stream->device()->at() << "\n";
}

void ConvertGtp::readTrackDefaults()
{
	Q_UINT8 num, volume, pan, chorus, reverb, phase, tremolo;
	currentStage = QString("readTrackDefaults");

	for (int i = 0; i < TRACK_MAX_NUMBER * 2; i++) {
		trackPatch[i] = getFrontAs!int(); // MIDI Patch
		(*stream) >> volume;                 // GREYFIX: volume
		(*stream) >> pan;                    // GREYFIX: pan
		(*stream) >> chorus;                 // GREYFIX: chorus
		(*stream) >> reverb;                 // GREYFIX: reverb
		(*stream) >> phase;                  // GREYFIX: phase
		(*stream) >> tremolo;                // GREYFIX: tremolo
		kdDebug() << "=== TrackDefaults: " << i <<
			" (patch=" << trackPatch[i] <<
			" vol=" << (int) volume <<
			" p=" << (int) pan <<
			" c=" << (int) chorus <<
			" ph=" << (int) phase <<
			" tr=" << (int) tremolo << "\n";

		(*stream) >> num;                    // 2 byte padding: must be 00 00
		if (num != 0)  kdDebug() << QString("1 of 2 byte padding: there is %1, must be 0\n").arg(num);
		(*stream) >> num;
		if (num != 0)  kdDebug() << QString("2 of 2 byte padding: there is %1, must be 0\n").arg(num);
	}
}

+/
