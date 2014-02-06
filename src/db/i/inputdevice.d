module db.i.inputdevice;

import db.instrument;
import db.i.syncsource;

import std.range;

enum InputEventType
{
	On,
	Off,
	Change,
}

struct InputEvent
{
	long timestamp;

	InputEventType event;

	int key;			// some id for the note, or a midi pitch value
	float velocity;		// velocity or amplitude. 0 on note up events
}

class InputDevice
{
	abstract @property InstrumentType instrumentType();

	@property InputEvent[] events() { return stream; }

	void Begin(SyncSource sync)
	{
		this.sync = sync;
	}

	void End()
	{
	}

	abstract void Update();	// NOTE: may be run on a high-frequency thread

	void Clear(long until = -1)
	{
		if(until == -1)
			stream = null;
		else
		{
			while(!stream.empty && stream[0].timestamp < until)
				stream.popFront();
		}
	}

	SyncSource sync;
	InputEvent[] stream;
}
