module db.i.scorekeeper;

import db.i.inputdevice;
import db.sequence;

class ScoreKeeper
{
	this(Sequence sequence, InputDevice input)
	{
		this.sequence = sequence;
		this.inputDevice = input;

		// create a score keeper for a given sequence and input stream
	}

	abstract void Update();

	Sequence sequence;
	InputDevice inputDevice;

	// TODO: events...
	// i think scorekeepers should have events that listeners can subscribe to, to be notified of significant player actions
//	Event noteHit;
//	Event noteMiss;
//	Event triggerStarPower;
}
