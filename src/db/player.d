module db.player;

import db.i.inputdevice;
import db.ui.inputmanager;
import db.profile;
import db.sequence;
import db.song;
import db.game : Game;
import db.lua;

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
	this(const(InputSource)* pInput)
	{
		pMenuInput = pInput;
		pInput.player = this;

		// defaults for instrument...
		input.device = Game.instance.getInputForDevice(pInput.device, pInput.deviceID);
		input.part = input.device.supportedParts[0];

		profile = new Profile();
		profile.name = "Player " ~ to!string(Game.instance.players.length + 1);
		profile.settings.colour = playerColours[Game.instance.players.length];

		data = createTable();
	}

	~this()
	{
		if(pMenuInput)
			pMenuInput.player = null;
	}

	Profile profile;

	const(InputSource)* pMenuInput; // perhaps we should have an array of these?

	struct Input
	{
		Part part;
		InputDevice device;
	}

	Input input;

	// TODO: I would like to support a feature where a player can play multiple instruments at once
	// UI would perhaps visualise the instruments available, players would tag themselves onto whichever one(s) they intend to play
//	Input[] inputs;

	string variation;
	string difficulty;

	LuaTable data;
}
