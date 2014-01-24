module db.scorekeepers.guitar;

import db.i.scorekeeper;
import db.i.inputdevice;
import db.sequence;

class GuitarScoreKeeper : ScoreKeeper
{
	this(Sequence sequence, InputDevice input)
	{
		super(sequence, input);
	}

	override void Update()
	{
		inputDevice.Update();

		// TODO: read drum triggers from input stream, match against sequence
		// drums are the easiest, so we'll start with that one
	}
}
