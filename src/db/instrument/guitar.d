module db.instrument.guitar;

import db.inputs.inputdevice;
import db.instrument;

enum TypeName = "guitar";
enum Parts = [ "realleadguitar", "realrhythmguitar" ];
enum ScoreKeeper = "realguitarscorekeeper";

enum GuitarFeatures
{
	Has7Strings,
	Has8Strings
}

class Guitar : Instrument
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
	return new Guitar(device, features);
}

immutable InstrumentDesc descriptor = InstrumentDesc(TypeName, Parts, ScoreKeeper, &createInstrument);
