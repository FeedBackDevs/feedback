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

	override void begin()
	{
		super.begin();

//		device.start(); // always running...
	}

	override void end()
	{
//		device.stop(); // always running...
	}

	MFMidiEvent[] getEvents(MFMidiEvent[] eventBuffer)
	{
		return device.getEvents(eventBuffer);
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
