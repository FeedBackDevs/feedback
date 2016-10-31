module db.instrument.bass;

import db.instrument;

enum TypeName = "bass";
enum Parts = [ "realbass" ];
enum ScoreKeeper = "realguitarscorekeeper";


package:

void registerType()
{
	registerInstrumentType(desc);
}


private:

immutable InstrumentDesc desc = InstrumentDesc(TypeName, Parts, ScoreKeeper);
