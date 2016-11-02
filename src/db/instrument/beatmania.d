module db.instrument.beatmania;

import db.inputs.inputdevice;
import db.instrument;

enum TypeName = "beatmania";
enum Parts = [ "beatmania" ];
enum ScoreKeeper = "basicscorekeeper";

class Beatmania : Instrument
{
	this(InputDevice device, uint features)
	{
		super(&descriptor, device, features);
	}

	override @property InputEvent[] events()
	{
		assert("!!");
		return null;
	}
}


package:

void registerType()
{
	registerInstrumentType(descriptor);
}


private:

Instrument createInstrument(InputDevice device, uint features)
{
	return new Beatmania(device, features);
}

immutable InstrumentDesc descriptor = InstrumentDesc(TypeName, Parts, ScoreKeeper, &createInstrument);
