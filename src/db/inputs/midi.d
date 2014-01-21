module db.inputs.midi;

import db.i.inputdevice;
import db.instrument;

class Midi : InputDevice
{
	this(int midiDeviceId, InstrumentType instrument)
	{
		deviceId = midiDeviceId;

		// input is either drums, keyboard, or guitar (via guitar->midi converter)
		// this needs to be configured; mini triggers mapped to inputs
	}

	override @property InstrumentType instrumentType() { return instrument; }

	override void Update()
	{
		// read midi stream, populate events
	}

	int deviceId;
	InstrumentType instrument;
}
