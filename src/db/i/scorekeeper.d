module db.i.scorekeeper;

import db.i.inputdevice;
import db.i.syncsource;
import db.sequence;

class ScoreKeeper
{
	this(Sequence sequence, InputDevice input)
	{
		this.sequence = sequence;
		this.inputDevice = input;

		// TODO: create a score keeper for a given sequence and input stream

		deviation = new long[sequence.notes.length];
	}

	void Begin(SyncSource sync)
	{
		inputDevice.Begin(sync);
	}

	abstract void Update();

	Sequence sequence;
	InputDevice inputDevice;

	long[] deviation;	// number of microseconds deviation from the proper time that the note was played

	// TODO: events...
	// i think scorekeepers should have events that listeners can subscribe to, to be notified of significant player actions
//	Event noteHit;
//	Event noteMiss;
//	Event triggerStarPower;
}
