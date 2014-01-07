module db.player;

import db.profile;
import db.instrument;
import db.song;


class Player
{
	Profile profile;

	Instrument instrument;

	int controller;	// controller id
	int audioInput;	// audio input device id
	int midiInput;	// midi input device id

	// TODO: I would like to support a feature where a player can play multiple instruments at once
	// UI would perhaps visualise the instruments available, players would tag themselves onto whichever one(s) they intend to play
}
