module db.instrument.vocals;

import db.instrument;

enum TypeName = "vocals";
enum Parts = [ "vocals" ];
enum ScoreKeeper = "voxscorekeeper";


package:

void registerType()
{
	registerInstrumentType(desc);
}


private:

immutable InstrumentDesc desc = InstrumentDesc(TypeName, Parts, ScoreKeeper);
