module db.inputs.midi;

import db.i.inputdevice;
import db.instrument;

class Midi : InputDevice
{
	this(int midiDeviceId, Instrument instrument)
	{
		deviceId = midiDeviceId;

		// input is either drums, keyboard, or guitar (via guitar->midi converter)
		// this needs to be configured; mini triggers mapped to inputs
	}

	@property InstrumentType instrumentType() { return instrument; }
	@property InputEvent[] events() { return stream; }

	void Update()
	{
		// read midi stream, populate events
	}

	void Clear(long until)
	{
		// clear all events before 'until'
	}

	int deviceId;
	InstrumentType instrument;
	InputEvent[] stream;
}
