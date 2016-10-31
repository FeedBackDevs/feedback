module db.instrument.beatmania;

import db.instrument;

enum TypeName = "beatmania";
enum Parts = [ "beatmania" ];
enum ScoreKeeper = "basicscorekeeper";


package:

void registerType()
{
	registerInstrumentType(desc);
}


private:

immutable InstrumentDesc desc = InstrumentDesc(TypeName, Parts, ScoreKeeper);
