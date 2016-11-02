module db.instrument.vocals;

import db.inputs.inputdevice;
import db.instrument;

enum TypeName = "vocals";
enum Parts = [ "vocals" ];
enum ScoreKeeper = "voxscorekeeper";

class Vocals : Instrument
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
	return new Vocals(device, features);
}

immutable InstrumentDesc descriptor = InstrumentDesc(TypeName, Parts, ScoreKeeper, &createInstrument);
