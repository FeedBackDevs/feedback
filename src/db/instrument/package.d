module db.instrument;

import db.i.syncsource;
import db.inputs.inputdevice;
import db.lua : noscript;
import db.game.player : Player;

import fuji.dbg : debugLog;

struct InstrumentDesc
{
	string type;
	string[] parts;
	string scopeKeeper;

	Instrument function(InputDevice device, uint features) createInstrument;
	Instrument function(InputDevice device) autoDetectInstrument;
}

enum InputEventType
{
	On,
	Off,
	Change,
}

struct InputEvent
{
	long timestamp;

	InputEventType event;

	int key;			// some id for the note, or a midi pitch value
	float velocity;		// velocity or amplitude. 0 on note up events
}

abstract class Instrument
{
	this(const InstrumentDesc* desc, InputDevice device, uint features)
	{
		this.desc = desc;
		this.device = device;
		this.features = features;
	}

	const InstrumentDesc* desc;

	InputDevice device;
	uint features;

	Player player; // TODO: should there be a reference to game.player in the instrument?

	@property long inputTime() const { return device.inputTime; }

	@property InputEvent[] events() { return stream; }

@noscript:

	void clear(long until = -1)
	{
		import std.range : empty, popFront;

		if (until == -1)
			stream = null;
		else
		{
			while (!stream.empty && stream[0].timestamp < until)
				stream.popFront();
		}
	}

	void update()
	{
		device.update();
	}

	void begin(string part)
	{
		this.part = part;
		device.begin();
	}
	void end()
	{
		device.end();
	}

protected:

	string part;

	InputEvent[] stream;
}

void registerInstrumentType(ref const(InstrumentDesc) desc)
{
	assert(findInstrument(desc.type) == null);
	types ~= desc;
}

const(InstrumentDesc)[] instrumentTypes()
{
	return types;
}

Instrument[] getInstruments()
{
	return instruments;
}

const(InstrumentDesc)* findInstrument(string name)
{
	foreach (ref i; types)
	{
		if (i.type[] == name[])
			return &i;
	}
	return null;
}

string instrumentForPart(string part)
{
	foreach (i; types)
	{
		foreach (p; i.parts)
		{
			if (p[] == part[])
				return i.type;
		}
	}
	return null;
}

void addInstrument(Instrument instrument)
{
	debugLog(2, "Add instrument: %s", instrument.device.name);

	instruments ~= instrument;
}

Instrument detectInstrument(InputDevice device)
{
	foreach (t; types)
	{
		if (!t.autoDetectInstrument)
			continue;
		Instrument i = t.autoDetectInstrument(device);
		if (i)
		{
			device.instrument = i;
			return i;
		}
	}
	return null;
}


void registerBuiltinInstrumentTypes()
{
	static import db.instrument.pckeyboard;
	db.instrument.pckeyboard.registerType();

	static import db.instrument.guitarcontroller;
	db.instrument.guitarcontroller.registerType();

	static import db.instrument.drums;
	db.instrument.drums.registerType();

	static import db.instrument.keyboard;
	db.instrument.keyboard.registerType();

	static import db.instrument.guitar;
	db.instrument.guitar.registerType();

	static import db.instrument.bass;
	db.instrument.bass.registerType();

	static import db.instrument.vocals;
	db.instrument.vocals.registerType();

	static import db.instrument.dance;
	db.instrument.dance.registerType();

	static import db.instrument.beatmania;
	db.instrument.beatmania.registerType();
}

private:

__gshared const(InstrumentDesc)[] types;
__gshared Instrument[] instruments;
