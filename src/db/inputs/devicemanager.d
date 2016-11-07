module db.inputs.devicemanager;

import fuji.input : MFInputDevice;
import fuji.midi;
import fuji.dbg;

import db.inputs.audio;
import db.inputs.controller;
import db.inputs.inputdevice;
import db.inputs.midi;
import db.instrument;
import db.sync.systime;


__gshared InputDevice[] devices;
__gshared Controller[] controllers;

__gshared MidiInputDevice[] midiIns;
__gshared MidiOutputDevice[] midiOuts;

enum MidiScan
{
	NotScanning,
	BeginScan,
	RequestIdentity,
	WaitingForResponse,
}
MidiScan midiScan;
int midiScanDevice;
SystemTimer midiScanTime;


Controller findController(MFInputDevice device, int deviceId)
{
	foreach (c; controllers)
	{
		if (c.isDevice(device, deviceId))
			return c;
	}
	return null;
}

void initInputDevices()
{
	import fuji.device;
	import fuji.input;

	foreach (i; 0..MFInput_GetNumKeyboards())
	{
		Controller c = new Controller(MFInputDevice.Keyboard, i);
		controllers ~= c;
		devices ~= c;

		Instrument instrument = detectInstrument(c);
		if (instrument)
			addInstrument(instrument);
	}

	// scan gamepads
	foreach (i; 0..MFInput_GetNumGamepads())
	{
		import fuji.input;

		Controller c = new Controller(MFInputDevice.Gamepad, i);
		controllers ~= c;
		devices ~= c;

		// detect instrument type... (we have a database of USB id's for various music game controllers)
		uint flags = MFInput_GetDeviceFlags(MFInputDevice.Gamepad, i);

		// instruments attached via adapters or proxy drivers can't be detected...
		if (flags & (MFGamepadFlags.IsAdapter | MFGamepadFlags.IsProxy))
			c.bCantDetectFeatures = true;
		else
		{
			Instrument instrument = detectInstrument(c);
			if (instrument)
				addInstrument(instrument);
		}
	}

	foreach (i; 0 .. getNumDevices(MFDeviceType.MidiInput))
	{
		auto dev = MidiInputDevice(i);
		if (dev.open(true))
		{
			dev.start();
			midiIns ~= dev;
		}
		else
			logWarning(2, "Couldn't open MIDI input device: '%s' (%s)", dev.name, dev.id);
	}
	foreach (i; 0 .. getNumDevices(MFDeviceType.MidiOutput))
	{
		auto dev = MidiOutputDevice(i);
		if (dev.open())
		{
			midiOuts ~= dev;
		}
		else
			logWarning(2, "Couldn't open MIDI output device: '%s' (%s)", dev.name, dev.id);
	}
	midiScan = MidiScan.BeginScan;
	midiScanTime = new SystemTimer();

	foreach (i; 0..getNumDevices(MFDeviceType.AudioCapture))
	{
		devices ~= new Audio(i);

		// check for signal...
	}
}

void updateInputDevices()
{
	// TODO: check added hardware
	// TODO: check removed hardware

	final switch (midiScan) with(MidiScan)
	{
		case NotScanning:
			break;

		case BeginScan:
			debugLog(2, "Beginning MIDI scan...");
			midiScan = RequestIdentity;
			midiScanDevice = 0;
			goto case RequestIdentity;

		case RequestIdentity:
		{
			if (midiScanDevice < midiOuts.length)
			{
				debugLog(2, "Scanning MIDI bus '%s' (%s)...", midiOuts[midiScanDevice].name, midiOuts[midiScanDevice].id);

				MFMidiEvent ev;
				ev.ev = MFMidiEventType.GeneralInformation_IdentityRequest;
				ev.channel = 0x7F; // request identity for all devices
				midiOuts[midiScanDevice].sendEvent(ev);

				midiScanTime.reset();

				midiScan = WaitingForResponse;
				break;
			}
			else
			{
				debugLog(2, "MIDI scan complete.");
				midiScan = NotScanning;
			}
			break;
		}

		case WaitingForResponse:
		{
			foreach (min; midiIns)
			{
				MFMidiEvent[64] eventBuffer;
				MFMidiEvent[] events;
				do
				{
					events = min.getEvents(eventBuffer[]);
					foreach (ref ev; events)
					{
						if (ev.ev == MFMidiEventType.GeneralInformation_IdentityReply)
						{
							auto midiDev = new Midi(min, midiOuts[midiScanDevice], ev.channel, &ev);
							devices ~= midiDev;

							// attempt to detect instrument...
							Instrument instrument = detectInstrument(midiDev);
							if (instrument)
								addInstrument(instrument);
						}
					}
				}
				while (events.length == eventBuffer.length);
			}

			if (midiScanTime.seconds >= 0.1)
			{
				midiScan = RequestIdentity;
				++midiScanDevice;
			}
			break;
		}
	}

	// TODO: midi active sync updates

	// TODO: check audio devices for silence or live input
}
