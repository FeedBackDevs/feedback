module db.player;

import db.i.inputdevice;
import db.profile;
import db.sequence;
import db.song;

class Player
{
	@property InputDevice device() { return input.device; }

	Profile profile;

	struct Input
	{
		Part part;
		InputDevice device;
	}

	Input input;

	// TODO: I would like to support a feature where a player can play multiple instruments at once
	// UI would perhaps visualise the instruments available, players would tag themselves onto whichever one(s) they intend to play
//	Input[] inputs;
}
