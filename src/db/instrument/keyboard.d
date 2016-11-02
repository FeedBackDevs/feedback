module db.instrument.keyboard;

import db.inputs.inputdevice;
import db.instrument;

enum TypeName = "keyboard";
enum Parts = [ "keyboard", "realkeyboard" ];
enum ScoreKeeper = "basicscorekeeper";

__gshared immutable ubyte[128] WhiteKeys =
[
	0,		// C0
	0|0x80,	// Cs0
	1,		// D0
	1|0x80,	// Ds0
	2,		// E0
	3,		// F0
	3|0x80,	// Fs0
	4,		// G0
	4|0x80,	// Gs0
	5,		// A0
	5|0x80,	// As0
	6,		// B0
	7,		// C1
	7|0x80,	// Cs1
	8,		// D1
	8|0x80,	// Ds1
	9,		// E1
	10,		// F1
	10|0x80,// Fs1
	11,		// G1
	11|0x80,// Gs1
	12,		// A1
	12|0x80,// As1
	13,		// B1
	14,		// C2
	14|0x80,// Cs2
	15,		// D2
	15|0x80,// Ds2
	16,		// E2
	17,		// F2
	17|0x80,// Fs2
	18,		// G2
	18|0x80,// Gs2
	19,		// A2
	19|0x80,// As2
	20,		// B2
	21,		// C3
	21|0x80,// Cs3
	22,		// D3
	22|0x80,// Ds3
	23,		// E3
	24,		// F3
	24|0x80,// Fs3
	25,		// G3
	25|0x80,// Gs3
	26,		// A3
	26|0x80,// As3
	27,		// B3
	28,		// C4
	28|0x80,// Cs4
	29,		// D4
	29|0x80,// Ds4
	30,		// E4
	31,		// F4
	31|0x80,// Fs4
	32,		// G4
	32|0x80,// Gs4
	33,		// A4
	33|0x80,// As4
	34,		// B4
	35,		// C5
	35|0x80,// Cs5
	36,		// D5
	36|0x80,// Ds5
	37,		// E5
	38,		// F5
	38|0x80,// Fs5
	39,		// G5
	39|0x80,// Gs5
	40,		// A5
	40|0x80,// As5
	41,		// B5
	42,		// C6
	42|0x80,// Cs6
	43,		// D6
	43|0x80,// Ds6
	44,		// E6
	45,		// F6
	45|0x80,// Fs6
	46,		// G6
	46|0x80,// Gs6
	47,		// A6
	47|0x80,// As6
	48,		// B6
	49,		// C7
	49|0x80,// Cs7
	50,		// D7
	50|0x80,// Ds7
	51,		// E7
	52,		// F7
	52|0x80,// Fs7
	53,		// G7
	53|0x80,// Gs7
	54,		// A7
	54|0x80,// As7
	55,		// B7
	56,		// C8
	56|0x80,// Cs8
	57,		// D8
	57|0x80,// Ds8
	58,		// E8
	59,		// F8
	59|0x80,// Fs8
	60,		// G8
	60|0x80,// Gs8
	61,		// A8
	61|0x80,// As8
	62,		// B8
	63,		// C9
	63|0x80,// Cs9
	64,		// D9
	64|0x80,// Ds9
	65,		// E9
	66,		// F9
	66|0x80,// Fs9
	67,		// G9
	67|0x80,// Gs9
	68,		// A9
	68|0x80,// As9
	69,		// B9
	70,		// C10
	70|0x80,// Cs10
	71,		// D10
	71|0x80,// Ds10
	72,		// E10
	73,		// F10
	73|0x80,// Fs10
	74		// G10
];

class Keyboard : Instrument
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
	return new Keyboard(device, features);
}

immutable InstrumentDesc descriptor = InstrumentDesc(TypeName, Parts, ScoreKeeper, &createInstrument);
