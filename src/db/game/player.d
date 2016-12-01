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
	this(const(InputSource)* pInputSource, Instrument instrument, string part = null, string type = null)
	{
		pMenuInput = pInputSource;

		if (instrument)
			defaultInstrument = instrument;
		else
		{
			Controller c = findController(pInputSource.device, pInputSource.deviceID);
			if (c)
				defaultInstrument = c.instrument;
		}

		addInstrument(instrument, part, type);

		profile = new Profile();
		profile.name = "Player " ~ to!string(Game.instance.players.length + 1);
		profile.settings.colour = playerColours[Game.instance.players.length];

		data = createTable();
	}

	~this()
	{
		foreach (i; parts)
		{
			if (i.instrument)
				i.instrument.player = null;
			i.instrument = null;
		}
	}

	Input* addInstrument(Instrument instrument, string part = null, string type = null)
	{
		if (instrument)
			instrument.player = this;

		if (!part && instrument)
			part = instrument.desc.parts[0];

		parts ~= Input(instrument, part, type);
		return &parts[$-1];
	}
	void removeInstrument(Instrument instrument)
	{
		foreach (i, part; parts)
		{
			if (part.instrument == instrument)
			{
				part.instrument.player = null;
				parts = parts[0..i] ~ parts[i+1..$];
				return;
			}
		}
	}

	Profile profile;

	const(InputSource)* pMenuInput; // perhaps we should have an array of these?

	Instrument defaultInstrument;

	struct Input
	{
		Instrument instrument;
		string part;
		string type;

		string variation;
		Difficulty difficulty = Difficulty.Easy;
	}
	Input[] parts;

	LuaTable data;
}
