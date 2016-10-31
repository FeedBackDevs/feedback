module db.inputs.midi;

import fuji.midi;

import db.tools.log;
import db.inputs.inputdevice;
import db.i.syncsource;
import db.instrument;
import db.chart.track : Track;
import db.game;
import db.scorekeepers.drums;

import fuji.fuji : MFBit;
import fuji.device;
import fuji.dbg;

class Midi : InputDevice
{
	this(MidiInputDevice input, MidiOutputDevice output, ubyte deviceId, const(MFMidiEvent)* identityResponse)
	{
		device = input;
		outputDevice = output;
		this.deviceId = deviceId;

		if (identityResponse)
		{
			vendor = identityResponse.generalInformation.identityReply.vendor;
			family = identityResponse.generalInformation.identityReply.family;
			member = identityResponse.generalInformation.identityReply.member;
			major = identityResponse.generalInformation.identityReply.major;
			minor = identityResponse.generalInformation.identityReply.minor;
		}

		if (input.name)
			deviceName = input.name.idup;
		else
			deviceName = input.id.idup;
	}

	override @property const(char)[] name() const
	{
		return deviceName;
	}

	override @property long inputTime() const
	{
		return Game.instance.performance.time - (deviceLatency + Game.instance.settings.midiLatency)*1_000;
	}

	void setDeviceName(string name)
	{
		deviceName = name;
	}

	override void Begin(SyncSource sync)
	{
		super.Begin(sync);

//		device.start(); // always running...
	}

	override void End()
	{
//		device.stop(); // always running...
	}

	override void Update()
	{
		// read midi stream, populate events
		MFMidiEvent[64] buffer;
		MFMidiEvent[] events;
		do
		{
			events = device.getEvents(buffer[]);

			foreach (ref e; events)
			{
				// we only care about trigger events...
				if (e.ev <= MFMidiEventType.NoteAftertouch)
				{
					InputEvent ie;
					ie.timestamp = cast(long)e.timestamp * 1_000 - (deviceLatency + Game.instance.settings.midiLatency)*1_000; // feedback times are microseconds
					ie.event = (e.ev == MFMidiEventType.NoteOff || (e.ev == MFMidiEventType.NoteOn && e.noteOn.velocity == 0)) ? InputEventType.Off : (e.ev == MFMidiEventType.NoteOn ? InputEventType.On : InputEventType.Change);
					ie.key = e.noteOn.note;
					ie.velocity = e.noteOn.velocity * (1 / 127.0f);

					// TODO: we probably want to apply some map to 'note' for the configured instrument type
					//...

					stream ~= ie;
				}
			}
		}
		while (events.length == buffer.length);
	}

	const uint vendor;
	const ushort family, member;
	const ushort major, minor;

private:
	MidiInputDevice device;
	MidiOutputDevice outputDevice;
	ubyte deviceId;

	string deviceName;
}
