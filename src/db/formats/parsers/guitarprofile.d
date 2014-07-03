module db.formats.parsers.guitarprofile;

import fuji.fuji;
import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import std.string;
import std.range;
import std.exception;

import db.tools.range;
import db.formats.parsers.midifile;

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

		// read attributes
		title = buffer.readDelphiString().idup;
		subtitle = buffer.readDelphiString().idup;
		artist = buffer.readDelphiString().idup;
		album = buffer.readDelphiString().idup;
		composer = buffer.readDelphiString().idup;
		if(ver >= 0x500)
			buffer.readDelphiString();
		copyright = buffer.readDelphiString().idup;
		transcriber = buffer.readDelphiString().idup;
		instructions = buffer.readDelphiString().idup;

		// notice lines
		int n = buffer.getFrontAs!int();
		foreach(i; 0..n)
		{
			auto line = buffer.readDelphiString();
			commments ~= i > 0 ? "\n" ~ line : line;
		}

		byte shuffleFeel;
		if(ver < 0x500)
			shuffleFeel = buffer.getFront();

		if(ver >= 0x400)
		{
			// Lyrics
			int lyricTrack = buffer.getFrontAs!int();		// GREYFIX: Lyric track number start

			for(int i = 0; i < LYRIC_LINES_MAX_NUMBER; i++)
			{
				int bar = buffer.getFrontAs!int();			// GREYFIX: Start from bar
				auto lyric = buffer.readWordPascalString();	// GREYFIX: Lyric line
			}
		}

		if(ver >= 0x500)
		{
			// page setup...
			buffer.getFrontN(ver > 0x500 ? 49 : 30);
			foreach(i; 0..11)
			{
				auto s = buffer.readDelphiString();
			}
		}

		tempo = buffer.getFrontAs!int();

		if(ver > 0x500)
			buffer.getFront(); // unknown?

		key = buffer.getFront();
		buffer.getFrontN(3); // unknown?

		if(ver >= 0x400)
			octave = buffer.getFront();

		readTrackDefaults(buffer);

		if(ver >= 0x500)
			buffer.getFrontN(42); // unknown?

		int numBars = buffer.getFrontAs!int();           // Number of bars
		assert(numBars > 0 && numBars < 16384, "Insane number of bars");
		measures = new MeasureInfo[numBars];

		int numTracks = buffer.getFrontAs!int();         // Number of tracks
		assert(numTracks > 0 && numTracks <= 32, "Insane number of tracks");
		tracks = new Track[numTracks];

		readBarProperties(buffer, shuffleFeel);
		readTrackProperties(buffer);

		readTabs(buffer);

		if(!buffer.empty)
		{
			int ex = buffer.getFrontAs!int();            // Exit code: 00 00 00 00
			assert(ex == 0, "File should terminate with 00 00 00 00");
			assert(buffer.empty, "File not ended!");
		}
	}

	enum
	{
		TRACK_MAX_NUMBER = 32,
		LYRIC_LINES_MAX_NUMBER = 5,
		STRING_MAX_NUMBER = 7
	};

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

		byte tn = 4;
		byte td = 4;
		ubyte numRepeats;
		ubyte altEnding;
		byte keysig;
		byte minor;

		byte shuffleFeel;

		string section;
		int colour;

		bool has(Bits bit) { return (bitmask & MFBit(bit)) != 0; }
	}

	struct Beat
	{
		enum Bits
		{
			Dotted,
			ChordDiagram,
			Text,
			Effects,
			MixChange,
			N_Tuplet,
			Silent
		}

		struct MixChange
		{
			byte patch;

			byte volume;
			byte pan;
			byte chorus;
			byte reverb;
			byte phase;
			byte tremolo;
			int tempo;

			ubyte volumeTrans;
			ubyte panTrans;
			ubyte chorusTrans;
			ubyte reverbTrans;
			ubyte phaseTrans;
			ubyte tremoloTrans;
			ubyte tempoTrans;

			ubyte maskAll;
		}

		enum PauseKind : ubyte
		{
			Empty = 0,
			Rest = 2
		}

		ubyte bitmask;

		byte length; // quarter_note / 2^length

		PauseKind pauseKind;
		int tuple;
		ChordDiagram* chord;
		string text;
		BeatEffect* effects;
		MixChange* mix;

		Note*[STRING_MAX_NUMBER] notes;

		bool has(Bits bit) { return (bitmask & MFBit(bit)) != 0; }
	}

	struct BeatEffect
	{
		enum Bits1
		{
			TapSlap = 5,
			StrokeEffect = 6
		}

		enum Bits2
		{
			Rasguedo,
			Pickstroke,
			TremoloBar
		}

		enum TapType : byte
		{
			None,
			Tapping,
			Slapping,
			Popping
		}

		enum StrokeType : byte
		{
			None,
			GoingUp,
			GoingDown
		}

		ubyte bitmask1;
		ubyte bitmask2;

		TapType tapType;
		Bend* bend;
		byte upStroke;
		byte downStroke;
		StrokeType strokeType;

		bool has(Bits1 bit) { return (bitmask1 & MFBit(bit)) != 0; }
		bool has(Bits2 bit) { return (bitmask2 & MFBit(bit)) != 0; }
	}

	struct Note
	{
		enum Bits
		{
			Duration,
			Dotted,
			Ghost,
			HasEffects,
			Dynamic,
			Type,
			Accentuated,
			Fingering // right/left handed
		}

		enum Type : ubyte
		{
			None = 0, // unknown?

			Normal = 1,
			Ghost = 2,
			Tie = 3
		}

		ubyte bitmask;

		Type type;

		byte length; // quarter_note / 2^length
		byte tuple;

		byte dynamic = 6;

		byte fret = -1;

		byte left = -1;
		byte right = -1;

		NoteEffect* effect;

		bool has(Bits bit) { return (bitmask & MFBit(bit)) != 0; }
	}

	struct NoteEffect
	{
		enum Bits1
		{
			Bend,
			HOPO,
			Slide,
			LetRing,
			GraceNote
		}

		enum Bits2
		{
			Staccato,
			PalmMute,
			TremloPicking,
			Slide,
			Harmonic,
			Trill,
			Vibrato
		}

		struct GraceNote
		{
			ubyte fret;
			byte dynamic;
			ubyte transition;
			ubyte duration;
			ubyte flags;
		}

		ubyte bitmask1;
		ubyte bitmask2;

		Bend* bend;

		GraceNote graceNote;

		byte tremloRate;
		byte slideType;
		byte harmonicType;

		byte trillFret;
		byte trillRate;

		bool has(Bits1 bit) { return (bitmask1 & MFBit(bit)) != 0; }
		bool has(Bits2 bit) { return (bitmask2 & MFBit(bit)) != 0; }
	}

	struct Bend
	{
		enum Type : byte
		{
			None,
			// bends
			Bend,
			BendAndRelease,
			BendAndReleaseAndBend,
			Prebend,
			PrebendAndRelease,
			// tremlo bar
			Dip,
			Dive,
			ReleaseUp,
			InvertedDip,
			Return,
			ReleaseDown
		}

		struct Point
		{
			enum Vibrato : byte
			{
				None,
				Fast,
				Average,
				Slow
			}

			int time; // 60th of note duration
			int value;  // 50 = 1 semitone
			Vibrato vibrato;
		}

		Type type;
		int value; // 50 = 1 semitone
		Point[] points;
	}

	struct ChordDiagram
	{
	}

	struct Measure
	{
		struct Beat
		{
			uint beat;
			int numBeats;
		}

		MeasureInfo *pInfo;
		Beat[2] voices;
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
			MIDINote tune;
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

	int ver;

	string title;
	string subtitle;
	string artist;
	string album;
	string composer;
	string copyright;
	string transcriber;
	string instructions;
	string commments;

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
			case "FICHIER GUITARE PRO v1":		ver = 0x100; break;
			case "FICHIER GUITARE PRO v1.01":	ver = 0x101; break;
			case "FICHIER GUITARE PRO v1.02":	ver = 0x102; break;
			case "FICHIER GUITARE PRO v1.03":	ver = 0x103; break;
			case "FICHIER GUITARE PRO v1.04":	ver = 0x104; break;
			case "FICHIER GUITAR PRO v2.20":	ver = 0x220; break;
			case "FICHIER GUITAR PRO v2.21":	ver = 0x221; break;
			case "FICHIER GUITAR PRO v3.00":	ver = 0x300; break;
			case "FICHIER GUITAR PRO v4.00":	ver = 0x400; break;
			case "FICHIER GUITAR PRO v4.06":	ver = 0x406; break;
			case "FICHIER GUITAR PRO L4.06":	ver = 0x406; break;
			case "FICHIER GUITAR PRO v5.00":	ver = 0x500; break;
			case "FICHIER GUITAR PRO v5.10":	ver = 0x510; break;
			default:
				assert(false, "Invalid file format: " ~ s);
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

	void readBarProperties(ref const(ubyte)[] buffer, byte shuffleFeel)
	{
		byte tn = 4, td = 4, ks, min;
		foreach(i, ref m; measures)
		{
			if(ver >= 0x500 && i > 0)
				buffer.getFront(); // unknown?

			m.bitmask = buffer.getFront();

			if(m.has(MeasureInfo.Bits.TSNumerator))
				tn = buffer.getFront();

			if(m.has(MeasureInfo.Bits.TSDenimonator))
				td = buffer.getFront();

			if(m.has(MeasureInfo.Bits.NumRepeats))
				m.numRepeats = buffer.getFront();

			if(ver < 0x500)
			{
				if(m.has(MeasureInfo.Bits.AlternativeEnding))
					m.altEnding = buffer.getFront();
			}

			if(m.has(MeasureInfo.Bits.NewSection))
			{
				m.section = buffer.readDelphiString().idup;
				m.colour = buffer.getFrontAs!int(); // color?
			}

			if(ver >= 0x500)
			{
				if(m.has(MeasureInfo.Bits.AlternativeEnding))
					m.altEnding = buffer.getFront();
			}

			if(m.has(MeasureInfo.Bits.NewKeySignature))
			{
				ks = buffer.getFront();		// GREYFIX: alterations_number
				min = buffer.getFront();		// GREYFIX: minor
			}

			if(ver >= 0x500)
			{
				if(m.has(MeasureInfo.Bits.TSNumerator) || m.has(MeasureInfo.Bits.TSDenimonator))
					buffer.getFrontN(4); // unknown?

				if(!m.has(MeasureInfo.Bits.AlternativeEnding))
					buffer.getFront();

				m.shuffleFeel = buffer.getFront();
			}
			else
			{
				m.shuffleFeel = shuffleFeel;
			}

			m.tn = tn;
			m.td = td;
			m.keysig = ks;
			m.minor = min;
		}
	}

	void readTrackProperties(ref const(ubyte)[] buffer)
	{
		ubyte bitmask;
		foreach(i, ref t; tracks)
		{
			if(ver > 0x500)
			{
				if(i == 0)
					bitmask = buffer.getFront(); // note: maybe this isn't he bitmask??
				buffer.getFront(); // unknown? (88...)
			}
			else if(ver == 0x500)
			{
				// what are these?
				buffer.getFront(); // (00, FF, FF, FF, 00, 00)
				buffer.getFront(); // (08, 08, 08, 48, 48, 09)
			}
			else
				bitmask = buffer.getFront();

			t.bitmask = bitmask;

			t.name = buffer.readPascalString(40).idup;    // Track name

			// Tuning information
			int numStrings = buffer.getFrontAs!int();
			assert(numStrings > 0 && numStrings <= STRING_MAX_NUMBER, "Insane number of strings");
			t.strings = new Track.String[numStrings];

			// Parse [0..string-1] with real string tune data in reverse order
			for(ptrdiff_t j = t.numStrings-1; j >= 0; --j)
			{
				int note = buffer.getFrontAs!int();
				assert(note < 128, "Invalid tuning");
				t.strings[j].tune = cast(MIDINote)note;
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

			if(ver >= 0x500)
			{
				buffer.getFrontN(ver > 0x500 ? 49 : 44);
				if(ver > 0x500)
				{
					buffer.readDelphiString();
					buffer.readDelphiString();
				}
			}

			assert(t.frets > 0 && t.frets <= 100, "Insane number of frets");
			assert(t.channel <= 16, "Insane MIDI channel 1");
			assert(t.channel2 >= 0 && t.channel2 <= 16, "Insane MIDI channel 2");

			// Fill remembered values from defaults
			t.patch = midiTracks[0][i].patch;
		}

		if(ver >= 0x500)
			buffer.getFrontN(ver == 0x500 ? 2 : 1); // unknown?
	}

	void readTabs(ref const(ubyte)[] buffer)
	{
		foreach(ref t; tracks)
			t.measures = new Measure[measures.length];

		foreach(i, ref mi; measures)
		{
			foreach(j, ref t; tracks)
			{
				if(ver >= 0x500 && (i != 0 || j != 0))
					buffer.getFront(); // unknown? Note: Doesn't seem to be present for the very first measure

				Measure* m = &t.measures[i];
				m.pInfo = &mi;

				readMeasure(buffer, t, m);
			}
		}
	}

	void readMeasure(ref const(ubyte)[] buffer, ref Track t, Measure* m)
	{
		int numVoices = ver >= 0x500 ? 2 : 1;
		foreach(int v; 0..numVoices)
		{
			int numBeats = buffer.getFrontAs!int();
			assert(numBeats >= 0 && numBeats <= 128, "insane number of beats");

			m.voices[v].beat = cast(uint)t.beats.length;
			m.voices[v].numBeats = numBeats;

			foreach(_; 0..numBeats)
				readBeat(buffer, t);
		}
	}

	void readBeat(ref const(ubyte)[] buffer, ref Track t)
	{
		Beat b;

		b.bitmask = buffer.getFront();

		if(b.has(Beat.Bits.Silent))
			b.pauseKind = buffer.getFrontAs!(Beat.PauseKind)(); // GREYFIX: pause_kind

		// Guitar Pro 4 beat lengths are as following:
		// -2 = 1    => 480     3-l = 5  2^(3-l)*15
		// -1 = 1/2  => 240           4
		//  0 = 1/4  => 120           3
		//  1 = 1/8  => 60            2
		//  2 = 1/16 => 30 ... etc    1
		//  3 = 1/32 => 15            0
		b.length = buffer.getFront();

		if(b.has(Beat.Bits.N_Tuplet))
		{
			b.tuple = buffer.getFrontAs!int();
			assert(b.tuple >= 3 && b.tuple <= 13, "Invalid tuple?");
		}

		if(b.has(Beat.Bits.ChordDiagram))
			b.chord = readChord(buffer, t.strings.length);

		if(b.has(Beat.Bits.Text))
			b.text = buffer.readDelphiString().idup;

		if(b.has(Beat.Bits.Effects))
			b.effects = readColumnEffects(buffer);

		if(b.has(Beat.Bits.MixChange))
		{
			Beat.MixChange* mix = new Beat.MixChange;

			mix.patch = buffer.getFront();

			if(ver >= 0x500)
				buffer.getFrontN(16);

			mix.volume = buffer.getFront();
			mix.pan = buffer.getFront();
			mix.chorus = buffer.getFront();
			mix.reverb = buffer.getFront();
			mix.phase = buffer.getFront();
			mix.tremolo = buffer.getFront();

			if(ver >= 0x500)
				readDelphiString(buffer); // tempo name

			mix.tempo = buffer.getFrontAs!int();

			// transitions
			if(mix.volume != -1)   mix.volumeTrans = buffer.getFront();
			if(mix.pan != -1)      mix.panTrans = buffer.getFront();
			if(mix.chorus != -1)   mix.chorusTrans = buffer.getFront();
			if(mix.reverb != -1)   mix.reverbTrans = buffer.getFront();
			if(mix.phase != -1)    mix.phaseTrans = buffer.getFront();
			if(mix.tremolo != -1)  mix.tremoloTrans = buffer.getFront();
			if(mix.tempo != -1)
			{
				mix.tempoTrans = buffer.getFront();
				if(ver > 0x500)
					buffer.getFront(); // unknown?
			}

			if(ver >= 0x400)
			{
				// bitmask: what should be applied to all tracks
				mix.maskAll = buffer.getFront();
			}

			if(ver >= 0x500)
			{
				buffer.getFront();
				if(ver > 0x500)
				{
					readDelphiString(buffer);
					readDelphiString(buffer);
				}
			}

			b.mix = mix;
		}

		int strings = buffer.getFront();
		if(strings)
		{
			foreach(s; 0..t.numStrings)
			{
				if(strings & (1 << 6-s))
					b.notes[t.numStrings - s - 1] = readNote(buffer);
			}
		}

		if(ver >= 0x500)
		{
			buffer.getFront(); // unknown?

			int read = buffer.getFront(); // unknown?
			//if(read == 8 || read == 10 || read == 24)
			if(read & 0x08)
				buffer.getFront(); // unknown?
		}

		t.beats ~= b;
	}

	Note* readNote(ref const(ubyte)[] buffer)
	{
		Note* n = new Note;
		n.bitmask = buffer.getFront();

		if(n.has(Note.Bits.Type))
			n.type = buffer.getFrontAs!(Note.Type)();

		if(ver < 0x500)
		{
			if(n.has(Note.Bits.Duration))
			{
				n.length = buffer.getFront();
				n.tuple = buffer.getFront();
			}
		}

		if(n.has(Note.Bits.Dotted))
		{}

		if(n.has(Note.Bits.Dynamic))
			n.dynamic = buffer.getFront();

		if(n.has(Note.Bits.Type))
			n.fret = buffer.getFront();

		if(n.has(Note.Bits.Fingering))
		{
			n.left = buffer.getFront();
			n.right = buffer.getFront();
		}

		if(ver >= 0x500)
		{
			if(n.has(Note.Bits.Duration))
				buffer.getFrontN(8); // duration data has changed?

			buffer.getFront(); // unknown?
		}

		if(n.has(Note.Bits.HasEffects))
			n.effect = readNoteEffect(buffer);

		return n;
	}

	NoteEffect* readNoteEffect(ref const(ubyte)[] buffer)
	{
		NoteEffect* e = new NoteEffect;

		e.bitmask1 = buffer.getFront();
		e.bitmask2 = ver >= 0x400 ? buffer.getFront() : 0;

		if(e.has(NoteEffect.Bits1.Bend))
			e.bend = readBend(buffer);
		if(e.has(NoteEffect.Bits1.GraceNote))
		{
			e.graceNote.fret = buffer.getFront();
			e.graceNote.dynamic = buffer.getFront();
			e.graceNote.transition = buffer.getFront();
			e.graceNote.duration = buffer.getFront();
			if(ver >= 0x500)
				e.graceNote.flags = buffer.getFront();
		}
		if(ver >= 0x400)
		{
			if(e.has(NoteEffect.Bits2.TremloPicking))
				e.tremloRate = buffer.getFront();
			if(e.has(NoteEffect.Bits2.Slide))
				e.slideType = buffer.getFront();
			if(e.has(NoteEffect.Bits2.Harmonic))
			{
				e.harmonicType = buffer.getFront();
				if(ver >= 0x500)
				{
					switch(e.harmonicType)
					{
						case 2: buffer.getFrontN(3); break;
						case 3: buffer.getFront(); break;
						case 1, 4, 5:
						default:
					}
				}
			}
			if(e.has(NoteEffect.Bits2.Trill))
			{
				e.trillFret = buffer.getFront();
				e.trillRate = buffer.getFront();
			}
		}

		return e;
	}

	Bend* readBend(ref const(ubyte)[] buffer)
	{
		Bend* b = new Bend;

		b.type = buffer.getFrontAs!(Bend.Type)();
		b.value = buffer.getFrontAs!int();
		int n = buffer.getFrontAs!int();
		b.points = new Bend.Point[n];
		foreach(i; 0..n)
		{
			b.points[i].time = buffer.getFrontAs!int();
			b.points[i].value = buffer.getFrontAs!int();
			b.points[i].vibrato = buffer.getFrontAs!(Bend.Point.Vibrato)();
		}

		return b;
	}

	BeatEffect* readColumnEffects(ref const(ubyte)[] buffer)
	{
		BeatEffect* e = new BeatEffect;
		e.bitmask1 = buffer.getFront();
		e.bitmask2 = ver >= 0x400 ? buffer.getFront() : 0;

		if(e.has(BeatEffect.Bits1.TapSlap))
		{
			ubyte effect = buffer.getFront();
			if(ver < 0x400)
			{
				switch(effect)
				{
					case 0:                    // GREYFIX: tremolo bar
						buffer.getFrontAs!int();
						break;
					case 1:                    // GREYFIX: tapping
						buffer.getFrontAs!int(); // ?
						break;
					case 2:                    // GREYFIX: slapping
						buffer.getFrontAs!int(); // ?
						break;
					case 3:                    // GREYFIX: popping
						buffer.getFrontAs!int(); // ?
						break;
					default:
						assert(false, "Unknown string torture effect");
				}
			}
			else
				e.tapType = cast(BeatEffect.TapType)effect;
		}
		if(e.has(BeatEffect.Bits2.TremoloBar))
			e.bend = readBend(buffer);
		if(e.has(BeatEffect.Bits1.StrokeEffect))
		{
			if(ver > 0x500)
			{
				e.upStroke = buffer.getFront();
				e.downStroke = buffer.getFront();
			}
			else
			{
				e.downStroke = buffer.getFront();
				e.upStroke = buffer.getFront();
			}
		}
		if(e.has(BeatEffect.Bits2.Pickstroke))
			e.strokeType = buffer.getFrontAs!(BeatEffect.StrokeType)();
/+
		if(fx_bitmask1 & 0x01)      // GREYFIX: GP3 column-wide vibrato
		{
		}
		if(fx_bitmask1 & 0x02)      // GREYFIX: GP3 column-wide wide vibrato (="tremolo" in GP3)
		{
		}
+/
		return e;
	}

	ChordDiagram* readChord(ref const(ubyte)[] buffer, size_t numStrings)
	{
		if(ver < 0x500)
		{
			ubyte v = buffer.getFront();
			if((v & 0x01) == 0)
			{
				string name = readDelphiString(buffer).idup;
				int firstFret = buffer.getFrontAs!int();
				if(firstFret != 0)
				{
					foreach(i; 0..6)
					{
						int fret = buffer.getFrontAs!int();
						if(i < numStrings)
						{
//							chord.addFretValue(i,fret);
						}
					}
				}
			}
			else
			{
				buffer.getFrontN(16);
				string name = buffer.readPascalString(21).idup;
				buffer.getFrontN(4);
				int firstFret = buffer.getFrontAs!int();
				foreach(i; 0..7)
				{
					int fret = buffer.getFrontAs!int();
					if(i < numStrings)
					{
//						chord.addFretValue(i,fret);
					}
				}
				buffer.getFrontN(32);
			}
		}
		else
		{
			buffer.getFrontN(17);
			string name = buffer.readPascalString(21).idup;
			buffer.getFrontN(4);
			int firstFret = buffer.getFrontAs!int();
			foreach(i; 0..7)
			{
				int fret = buffer.getFrontAs!int();
				if(i < numStrings)
				{
//					chord.addFretValue(i,fret);
				}
			}
			buffer.getFrontN(32);
		}

		return null;
/+
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
+/
	}
}


private:

const(char)[] readPascalString(ref inout(ubyte)[] buffer, int maxlen)
{
	ubyte l = buffer.getFront();
	auto s = buffer.getFrontN(l);
	if(maxlen - l > 0)
		buffer.getFrontN(maxlen - l);
	return cast(const(char)[])s;
}

const(char)[] readWordPascalString(ref inout(ubyte)[] buffer)
{
	int l = buffer.getFrontAs!int();
	return cast(const(char)[])buffer.getFrontN(l);
}

const(char)[] readDelphiString(ref inout(ubyte)[] buffer)
{
	int maxl = buffer.getFrontAs!int();
	MFEndian_LittleToHost(&maxl);

	ubyte l = buffer.getFront();
	assert(maxl == l + 1, "first word doesn't match second byte");

	return cast(const(char)[])buffer.getFrontN(l);
}
