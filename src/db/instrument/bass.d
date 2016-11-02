module db.instrument.bass;

import db.inputs.inputdevice;
import db.instrument;

enum TypeName = "bass";
enum Parts = [ "realbass" ];
enum ScoreKeeper = "realguitarscorekeeper";

class Bass : Instrument
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
	return new Bass(device, features);
}

immutable InstrumentDesc descriptor = InstrumentDesc(TypeName, Parts, ScoreKeeper, &createInstrument);
