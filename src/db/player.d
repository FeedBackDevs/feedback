module db.player;

import db.instrument;
import db.song;

struct Score
{
	int Score(Instrument instrument, Difficulty difficulty)
	{
		return Difficulty.Count*instrument + difficulty;
	}

private:
	int[Difficulty.Count*Instrument.Count] score;
}

class Player
{
	// TODO: manage user profiles somehow...
	// FaceBook connect? Google accounts? Steam? OpenFeint? Etc...

	string name;

	Instrument instrument;

	int controller;	// controller id
	int audioInput;	// audio input device id
	int midiInput;	// midi input device id

	Score[string] scores;

	// TODO: visual stuff?
	// colours, models, etc...
}
