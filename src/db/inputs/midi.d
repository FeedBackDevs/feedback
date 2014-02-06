module db.inputs.midi;

import fuji.midi;

import db.i.inputdevice;
import db.i.syncsource;
import db.instrument;

class Midi : InputDevice
{
	this(int midiDeviceId)
	{
		deviceId = midiDeviceId;

		pMidiInput = MFMidi_OpenInput(midiDeviceId, true);

		// input is either drums, keyboard, or guitar (via guitar->midi converter)
		// this needs to be configured; mini triggers mapped to inputs

		// HACK: assume keyboard for now?
		instrument = InstrumentType.Keyboard;
	}

	~this()
	{
		MFMidi_CloseInput(pMidiInput);
	}

	override @property InstrumentType instrumentType() { return instrument; }

	override void Begin(SyncSource sync)
	{
		super.Begin(sync);

		MFMidi_Start(pMidiInput);
	}

	override void End()
	{
		MFMidi_Stop(pMidiInput);
	}

	override void Update()
	{
		// read midi stream, populate events
		MFMidiEvent[64] buffer;
		MFMidiEvent[] events;
		while((events = MFMidi_GetEvents(pMidiInput, buffer[])) != null)
		{
			foreach(e; events)
			{
				// we only care about trigger events...
				if(e.command >= 0x80 || e.command <= 0xA0)
				{
					InputEvent ie;
					ie.timestamp = cast(long)e.timestamp * 1000; // feedback times are microseconds
					ie.event = (e.command == 0x80 || (e.command == 0x90 && e.data1 == 0)) ? InputEventType.Off : (e.command == 0x90 ? InputEventType.On : InputEventType.Change);
					ie.key = e.data0;
					ie.velocity = e.data1 * (1 / 255.0f);

					// TODO: we probably want to apply some map to 'note' for the configured instrument type
					//...

					stream ~= ie;
				}
			}
		}
	}

	MFMidiInput* pMidiInput;
	int deviceId;

	InstrumentType instrument;
}

Midi[] DetectMidiDevices()
{
	Midi[] devices;

	foreach(i; 0..MFMidi_GetNumDevices())
		devices ~= new Midi(i);

	return devices;
}
