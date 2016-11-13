module db.game.player;

import db.game : Game;
import db.chart : Difficulty;
import db.inputs.controller : Controller;
import db.inputs.devicemanager : findController;
import db.instrument : Instrument, getInstruments;
import db.profile : Profile;
import db.lua;
import db.ui.inputmanager : InputSource;

import fuji.vector;

import std.conv : to;


private immutable MFVector[] playerColours =
[
	MFVector.red,
	MFVector.green,
	MFVector.blue,
	MFVector.yellow,
	MFVector.magenta,
	MFVector.cyan,
	MFVector.white,
	MFVector.black
];

class Player
{
	this(const(InputSource)* pUiInputSource, Instrument instrument)
	{
		pMenuInput = pUiInputSource;

		if (instrument)
		{
			input.instrument = instrument;
			input.part = instrument.desc.parts[0];
		}
		else
		{
			Controller controller = findController(pMenuInput.device, pMenuInput.deviceID);
			if (controller && controller.instrument)
			{
				input.instrument = controller.instrument;
				input.part = controller.instrument.desc.parts[0];
			}
			else
			{
				// first available instrument??
				Instrument[] instruments = getInstruments();
				if (instruments.length > 0)
				{
					input.instrument = instruments[0];
					input.part = instruments[0].desc.parts[0];
				}
			}
		}

		profile = new Profile();
		profile.name = "Player " ~ to!string(Game.instance.players.length + 1);
		profile.settings.colour = playerColours[Game.instance.players.length];

		data = createTable();
	}

	Profile profile;

	const(InputSource)* pMenuInput; // perhaps we should have an array of these?

	struct Input
	{
		string part;
		Instrument instrument;
	}
	Input input;

	// TODO: I would like to support a feature where a player can play multiple instruments at once
	// UI would perhaps visualise the instruments available, players would tag themselves onto whichever one(s) they intend to play
//	Input[] inputs;

	string variation;
	Difficulty difficulty;

	LuaTable data;
}
