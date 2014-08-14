module db.formats.parsers.midifile;

import fuji.fuji;
import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import std.string;
import std.range;
import std.exception;

import db.tools.range;

enum MIDIEventType : ubyte
{
	NoteOff = 0x80,
	NoteOn = 0x90,
	KeyAfterTouch = 0xA0,
	ControlChange = 0xB0,
	ProgramChange = 0xC0,
	ChannelAfterTouch = 0xD0,
	PitchWheel = 0xE0,
	SYSEX = 0xF0,
	Custom = 0xFF
}

enum MIDIEvents : ubyte
{
	SequenceNumber = 0x00, // Sequence Number
	Text = 0x01, // Text
	Copyright = 0x02, // Copyright
	TrackName = 0x03, // Sequence/Track Name
	Instrument = 0x04, // Instrument
	Lyric = 0x05, // Lyric
	Marker = 0x06, // Marker
	CuePoint = 0x07, // Cue Point
	PatchName = 0x08, // Program (Patch) Name
	PortName = 0x09, // Device (Port) Name
	EndOfTrack = 0x2F, // End of Track
	Tempo = 0x51, // Tempo
	SMPTE = 0x54, // SMPTE Offset
	TimeSignature = 0x58, // Time Signature
	KeySignature = 0x59, // Key Signature
	Custom = 0x7F, // Proprietary Event
}

struct MThd_Chunk
{
	ubyte[4] id;   // 'M','T','h','d'
	uint	 length;

	ushort	 format;
	ushort	 numTracks;
	ushort	 ticksPerBeat;
}

struct MTrk_Chunk
{
	ubyte[4] id;   // 'M','T','r','k' */
	uint	 length;
}

class MIDIFile
{
	this(const(char)[] filename)
	{
		ubyte[] file = enforce(MFFileSystem_Load(filename), "Couldn't load .midi file!");
		this(file);
	}

	this(const(ubyte)[] buffer)
	{
		if(buffer[0..4] == "RIFF")
		{
			buffer.popFrontN(8);
			assert(buffer[0..4] == "RMID", "Not a midi file...");
			buffer.popFrontN(4);
		}

		MThd_Chunk *pHd = cast(MThd_Chunk*)buffer.ptr;

		assert(pHd.id[] == "MThd", "Not a midi file...");
		MFEndian_BigToHost(pHd);

		format = pHd.format;
		ticksPerBeat = pHd.ticksPerBeat;
		tracks = new MIDIEvent[][pHd.numTracks];

		buffer.popFrontN(8 + pHd.length);

		// we will only deal with type 1 midi files here..
		assert(pHd.format == 1, "Invalid midi type.");

		for(size_t t = 0; t < pHd.numTracks && !buffer.empty; ++t)
		{
			MTrk_Chunk *pTh = cast(MTrk_Chunk*)buffer.ptr;
			MFEndian_BigToHost(pTh);

			buffer.popFrontN(MTrk_Chunk.sizeof);

			if(pTh.id[] == "MTrk")
			{
				const(ubyte)[] track = buffer[0..pTh.length];
				uint tick = 0;
				ubyte lastStatus = 0;

				while(!track.empty)
				{
					uint delta = ReadVarLen(track);
					tick += delta;
					ubyte status = track.getFront();

					MIDIEvent ev;
					bool appendEvent = true;

					if(status == 0xFF)
					{
						// non-midi event
						MIDIEvents type = cast(MIDIEvents)track.getFront();
						uint bytes = ReadVarLen(track);

						// get the event bytes
						const(ubyte)[] event = track.getFrontN(bytes);

						// read event
						switch(type) with(MIDIEvents)
						{
							case MIDIEvents.SequenceNumber:
								{
									static int sequence = 0;

									if(!bytes)
										ev.sequenceNumber = sequence++;
									else
									{
										ushort seq = event.getFrontAs!ushort;
										MFEndian_BigToHost(&seq);
										ev.sequenceNumber = cast(int)seq;
									}
									break;
								}
							case Text:
							case Copyright:
							case TrackName:
							case Instrument:
							case Lyric:
							case Marker:
							case CuePoint:
							case PatchName:
							case PortName:
								{
									ev.text = (cast(const(char)[])event).idup;
									break;
								}
							case EndOfTrack:
								{
									assert(track.length == 0, "Track seems to end prematurely...");
									break;
								}
							case Tempo:
								{
									ev.tempo.microsecondsPerBeat = event[0] << 16;
									ev.tempo.microsecondsPerBeat |= event[1] << 8;
									ev.tempo.microsecondsPerBeat |= event[2];
									break;
								}
							case SMPTE:
								{
									ev.smpte.hours = event[0];
									ev.smpte.minutes = event[1];
									ev.smpte.seconds = event[2];
									ev.smpte.frames = event[3];
									ev.smpte.subFrames = event[4];
									break;
								}
							case TimeSignature:
								{
									ev.timeSignature.numerator = event[0];
									ev.timeSignature.denominator = event[1];
									ev.timeSignature.clocks = event[2];
									ev.timeSignature.d = event[3];
									break;
								}
							case KeySignature:
								{
									ev.keySignature.sf = event[0];
									ev.keySignature.minor = event[1];
									break;
								}
							case Custom:
								{
									ev.data = event.idup;
									break;
								}
							default:
								// TODO: are there any we missed?
								appendEvent = false;
						}

						if(appendEvent)
							ev.subType = type;
					}
					else if(status == 0xF0)
					{
						uint bytes = ReadVarLen(track);

						// get the SYSEX bytes
						const(ubyte)[] event = track.getFrontN(bytes);
						ev.data = event.idup;
					}
					else
					{
						if(status < 0x80)
						{
							// HACK: stick the last byte we popped back on the front...
							track = (track.ptr - 1)[0..track.length+1];
							status = lastStatus;
						}
						lastStatus = status;

						int eventType = status & 0xF0;

						int param1 = ReadVarLen(track);
						int param2;
						if(eventType != MIDIEventType.ProgramChange && eventType != MIDIEventType.ChannelAfterTouch)
							param2 = ReadVarLen(track);

						switch(eventType)
						{
							case MIDIEventType.NoteOn:
							case MIDIEventType.NoteOff:
								{
									ev.note.channel = status & 0x0F;
									ev.note.note = param1;
									ev.note.velocity = param2;
									break;
								}
							default:
								// TODO: handle other event types?
								appendEvent = false;
						}
					}

					// append event to track
					if(appendEvent)
					{
						ev.tick = tick;
						ev.delta = delta;
						ev.type = status != 0xFF ? status & 0xF0 : status;
						if(status != 0xFF)
							ev.subType = status & 0x0F;

						tracks[t] ~= ev;
					}
				}
			}

			buffer.popFrontN(pTh.length);
		}
	}

	void WriteText(string filename)
	{
		import std.conv;
		import std.digest.digest;

		string file = .format("MIDI\r\nformat = %d\r\nresolution = %d\r\n", format, ticksPerBeat);
		foreach(i, t; tracks)
		{
			file ~= .format("Track %d\r\n", i+1);
			foreach(e; t)
			{
				file ~= .format("  %06d %s: ", e.tick, (cast(MIDIEventType)e.type).to!string);

				switch(e.type)
				{
					case MIDIEventType.Custom:
						file ~= .format("%s ", (cast(MIDIEvents)e.subType).to!string);

						switch(e.subType) with(MIDIEvents)
						{
							case MIDIEvents.SequenceNumber:
								file ~= .format("%d", e.sequenceNumber);
								break;
							case Text:
							case Copyright:
							case TrackName:
							case Instrument:
							case Lyric:
							case Marker:
							case CuePoint:
							case PatchName:
							case PortName:
								file ~= .format("%s", e.text);
								break;
							case EndOfTrack:
								break;
							case Tempo:
								file ~= .format("%d (%fbpm) ", e.tempo.microsecondsPerBeat, 60000000.0 / e.tempo.microsecondsPerBeat);
								break;
							case SMPTE:
								file ~= .format("%d:%d:%d:%d:%d", e.smpte.hours, e.smpte.minutes, e.smpte.seconds, e.smpte.frames, e.smpte.subFrames);
								break;
							case TimeSignature:
								file ~= .format("%d %d %d %d", e.timeSignature.numerator, e.timeSignature.denominator, e.timeSignature.clocks, e.timeSignature.d);
								break;
							case KeySignature:
								file ~= .format("%d %d", e.keySignature.sf, e.keySignature.minor);
								break;
							case Custom:
								file ~= toHexString(e.data);
								break;
							default:
								break;
						}

						break;
					case MIDIEventType.SYSEX:
						file ~= toHexString(e.data);
						break;
					default:
						file ~= .format("[%d] %d, %d", e.note.channel+1, e.note.note, e.note.velocity);
						break;
				}

				file ~= "\r\n";
			}
		}

		MFFileSystem_Save(filename, cast(ubyte[])file);
	}

	int format;
	int ticksPerBeat;

	MIDIEvent[][] tracks;
}

struct MIDIEvent
{
	bool isEvent(MIDIEvents e)
	{
		return type == MIDIEventType.Custom && subType == e;
	}

	struct Note
	{
		ubyte channel;
		int note;
		int velocity;
	}
	struct Tempo
	{
		int microsecondsPerBeat;
	}
	struct SMPTE
	{
		ubyte hours, minutes, seconds, frames, subFrames;
	}
	struct TimeSignature
	{
		ubyte numerator, denominator;
		ubyte clocks;
		ubyte d;
	}
	struct KeySignature
	{
		ubyte sf;
		ubyte minor;
	}

	uint tick;
	uint delta;
	ubyte type;
	ubyte subType;

	union
	{
		Note note;
		int sequenceNumber;
		string text;
		Tempo tempo;
		SMPTE smpte;
		TimeSignature timeSignature;
		KeySignature keySignature;
		immutable(ubyte)[] data;
	}
}

void WriteVarLen(ref ubyte[] buffer, uint value)
{
	uint buf;
	buf = value & 0x7F;

	while((value >>= 7))
	{
		buf <<= 8;
		buf |= ((value & 0x7F) | 0x80);
	}

	while(1)
	{
		buffer ~= cast(ubyte)(buf & 0xFF);
		if(buf & 0x80)
			buf >>= 8;
		else
			break;
	}
}

uint ReadVarLen(ref const(ubyte)[] buffer)
{
	uint value;
	ubyte c;

	value = buffer[0];
	buffer = buffer[1..$];

	if(value & 0x80)
	{
		value &= 0x7F;
		do
		{
			c = buffer[0];
			buffer = buffer[1..$];
			value = (value << 7) + (c & 0x7F);
		}
		while(c & 0x80);
	}

	return value;
}

enum MIDINote : byte
{
	C0 = 0,
	Cs0,
	D0,
	Ds0,
	E0,
	F0,
	Fs0,
	G0,
	Gs0,
	A0,
	As0,
	B0,
	C1,
	Cs1,
	D1,
	Ds1,
	E1,
	F1,
	Fs1,
	G1,
	Gs1,
	A1,
	As1,
	B1,
	C2,
	Cs2,
	D2,
	Ds2,
	E2,
	F2,
	Fs2,
	G2,
	Gs2,
	A2,
	As2,
	B2,
	C3,
	Cs3,
	D3,
	Ds3,
	E3,
	F3,
	Fs3,
	G3,
	Gs3,
	A3,
	As3,
	B3,
	C4,
	Cs4,
	D4,
	Ds4,
	E4,
	F4,
	Fs4,
	G4,
	Gs4,
	A4,
	As4,
	B4,
	C5,
	Cs5,
	D5,
	Ds5,
	E5,
	F5,
	Fs5,
	G5,
	Gs5,
	A5,
	As5,
	B5,
	C6,
	Cs6,
	D6,
	Ds6,
	E6,
	F6,
	Fs6,
	G6,
	Gs6,
	A6,
	As6,
	B6,
	C7,
	Cs7,
	D7,
	Ds7,
	E7,
	F7,
	Fs7,
	G7,
	Gs7,
	A7,
	As7,
	B7,
	C8,
	Cs8,
	D8,
	Ds8,
	E8,
	F8,
	Fs8,
	G8,
	Gs8,
	A8,
	As8,
	B8,
	C9,
	Cs9,
	D9,
	Ds9,
	E9,
	F9,
	Fs9,
	G9,
	Gs9,
	A9,
	As9,
	B9,
	C10,
	Cs10,
	D10,
	Ds10,
	E10,
	F10,
	Fs10,
	G10
}
