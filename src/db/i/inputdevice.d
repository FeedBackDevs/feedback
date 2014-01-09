module db.i.inputdevice;

import db.instrument;


struct InputEvent
{
	long timestamp;

	int note;			// some id for the note, or a midi pitch value
	int velocity;		// velocity or amplitude. 0 on note up events
}

interface InputDevice
{
	@property InstrumentType instrumentType();

	@property InputEvent[] events();

	void Update();			// NOTE: may be run on a high-frequency thread
	void Clear(long until);	// clear input events <= the given offset
}
