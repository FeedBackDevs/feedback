module db.inputs.controller;

import db.i.inputdevice;
import db.instrument;

class Controller : InputDevice
{
	this(int controllerId)
	{
		this.controllerId = controllerId;

		// detect instrument type... (we have a database of USB id's for various music game controllers)
	}

	@property InstrumentType instrumentType() { return instrument; }
	@property InputEvent[] events() { return stream; }

	void Update()
	{
		// read controller, populate events
	}

	void Clear(long until)
	{
		// clear all events before 'until'
	}

	int controllerId;
	InstrumentType instrument;
	InputEvent[] stream;
}
