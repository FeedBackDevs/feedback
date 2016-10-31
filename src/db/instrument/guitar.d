module db.instrument.guitar;

import db.instrument;

enum TypeName = "guitar";
enum Parts = [ "realleadguitar", "realrhythmguitar" ];
enum ScoreKeeper = "realguitarscorekeeper";

enum GuitarFeatures
{
	Has7Strings,
	Has8Strings
}


package:

void registerType()
{
	registerInstrumentType(desc);
}


private:

immutable InstrumentDesc desc = InstrumentDesc(TypeName, Parts, ScoreKeeper);
