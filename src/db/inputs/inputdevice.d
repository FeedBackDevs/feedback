module db.inputs.inputdevice;

import db.i.syncsource : SyncSource;
import db.instrument : Instrument;

import luad.base : noscript;

import std.range : empty, popFront;

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
	long deviceLatency;

	abstract @property const(char)[] name() const;

	abstract @property long inputTime() const;

	@property InputEvent[] events() { return stream; }

@noscript:

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
		if (until == -1)
			stream = null;
		else
		{
			while (!stream.empty && stream[0].timestamp < until)
				stream.popFront();
		}
	}

	Instrument instrument;

	SyncSource sync;
	InputEvent[] stream;
}
