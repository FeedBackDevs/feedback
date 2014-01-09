module db.scorekeepers.drums;

import db.i.scorekeeper;
import db.i.inputdevice;
import db.sequence;

class DrumsScoreKeeper : ScoreKeeper
{
	this(Sequence sequence, InputDevice input)
	{
		super(sequence, input);
	}

	override void Update()
	{
		// TODO: read drum triggers from input stream, match against sequence
		// drums are the easiest, so we'll start with that one
	}
}
