module db.instrument.dance;

import db.inputs.inputdevice;
import db.instrument;

enum TypeName = "dance";
enum Parts = [ "dance" ];
enum ScoreKeeper = "basicscorekeeper";

enum DanceFeatures
{
	HasDancePads,	// Up, Down, Left, Right
	HasSoloPads,	// Includes UpLeft, UpRight
	HasPumpPads,	// Corners and, Center
	Has8Pads,		// 8 panels (no center)
	Has9Pads		// 9 panels
}

enum DanceNotes
{
	Left,
	Down,
	Up,
	Right,
	UpLeft,
	UpRight,
	DownLeft,
	DownRight,
	Center,
	LeftHand,
	RightHand,
	LeftHandBelow,
	RightHandBelow,
	Left2,
	Down2,
	Up2,
	Right2,
	UpLeft2,
	UpRight2,
	DownLeft2,
	DownRight2,
	Center2,
	LeftHand2,
	RightHand2,
	LeftHandBelow2,
	RightHandBelow2
}

enum DanceFlags
{
	Roll,
	Mine,
	Lift,
	Fake,
	Shock,
	Sound,	// sound index should be found in the top byte
}

class Dance : Instrument
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
	return new Dance(device, features);
}

immutable InstrumentDesc descriptor = InstrumentDesc(TypeName, Parts, ScoreKeeper, &createInstrument);
