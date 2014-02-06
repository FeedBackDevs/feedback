module db.i.scorekeeper;

import db.i.inputdevice;
import db.i.syncsource;
import db.sequence;

import std.signals;

class ScoreKeeper
{
	this(Sequence sequence, InputDevice input)
	{
		this.sequence = sequence;
		this.inputDevice = input;
	}

	void Begin(SyncSource sync)
	{
		inputDevice.Begin(sync);
	}

	abstract void Update();

	Sequence sequence;
	InputDevice inputDevice;

	long tolerance = 50;

	// shared
	mixin Signal!(int, long) noteHit;	// (key, precision) precision is microseconds from the precise note time
	mixin Signal!(int) noteMiss;		// (key)
	mixin Signal!(int) trigger;			// (trigger type)
}
