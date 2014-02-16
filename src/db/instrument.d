module db.instrument;

import db.i.inputdevice;
import db.inputs.controller;
import db.inputs.midi;


// list of instruments i've encountered in various music games
// obviously, many of these would not be supported (... at first?) ;)
// options to keep in mind when writing code or making UI choices
enum InstrumentType
{
	Unknown = -1,

	GuitarController,	// guitatr controller
	Drums,				// drums
	Vocals,				// vocals
	Keyboard,			// keyboard
	Guitar,				// (real) guitar
	Bass,				// (real) bass
	DJ,					// DJ controller

	// Bemani
	// NOTE: Guitar Freak, Drum Mania, and Keyboardmania can be factored into the existing parts
	Dance,				// dance controller
	Beatmania,			// 
	PNM,				// Pop'n Music

	// Silly
	Conga,
	Taiko,

	Count
}


// guitar controller
enum GuitarFeatures
{
	HasTilt,
	HasSolo,
	HasSlider,
	HasPickupSwitch
}

enum GuitarInput
{
	Green,
	Red,
	Yellow,
	Blue,
	Orange,
	Strum,
	Whammy,
	Tilt,
	TriggerSpecial,
	Switch,

	Solo = 0x10,
	Slider = 0x20,
}

enum GuitarNotes
{
	Green,
	Red,
	Yellow,
	Blue,
	Orange,
	Open
}

enum GuitarNoteFlags
{
	HOPO,	// hammer-on/pull-off
	Tap		// tap note
}

// drums
enum DrumFeatures
{
	Has4Drums,
	HasCymbals,
	Has3Cymbals,
	HasHatPedal,
	HasRims,
	HasVelocity,
	HasCymbalZone
}

enum DrumInput
{
	Snare,
	Cymbal1,
	Tom1,
	Cymbal2,
	Tom2,
	Cymbal3,
	Tom3,
	Kick,
	HatPedal,

	Secondary = 0x10,	// rims for drums, bell for cymbals
}

enum DrumNotes
{				// RB kit		GH kit
	Snare,		//   R			  R
	Hat,		//   Y			  Y
	Tom1,		//   Y			  B
	Crash,		//   B			  Y/O?
	Tom2,		//   B			  B(/G?)
	Ride,		//   G			  O
	Tom3,		//   G			  G
	Kick,
}

enum DrumNoteFlags
{
	DoubleKick,	// double kick notes are hidden in single-kick mode
	OpenHat,	// interesting if drum kit has a hat pedal
	RimShot,	// if drums have rims
	CymbalBell,	// if cymbals have zones
}

// keyboard


// dance mat
enum DanceFeatures
{
	HasDancePads,	// Up, Down, Left, Right
	HasSoloPads,	// UpLeft, UpRight
	HasPumpPads		// UpLeft, UpRight, DownLeft, DownRight, Center
}

enum DanceNotes
{
	Left,
	Up,
	Down,
	Right,
	UpLeft,
	UpRight,
	Left2,
	Up2,
	Down2,
	Right2,
	UpLeft2,
	UpRight2
}

// misc
enum Notes
{
	C0 = 0,
	Cs0,
	D0,
	Ds0,
	E0,
	F0,
	Fs0,
	G0,
	Gs0,
	A0,
	As0,
	B0,
	C1,
	Cs1,
	D1,
	Ds1,
	E1,
	F1,
	Fs1,
	G1,
	Gs1,
	A1,
	As1,
	B1,
	C2,
	Cs2,
	D2,
	Ds2,
	E2,
	F2,
	Fs2,
	G2,
	Gs2,
	A2,
	As2,
	B2,
	C3,
	Cs3,
	D3,
	Ds3,
	E3,
	F3,
	Fs3,
	G3,
	Gs3,
	A3,
	As3,
	B3,
	C4,
	Cs4,
	D4,
	Ds4,
	E4,
	F4,
	Fs4,
	G4,
	Gs4,
	A4,
	As4,
	B4,
	C5,
	Cs5,
	D5,
	Ds5,
	E5,
	F5,
	Fs5,
	G5,
	Gs5,
	A5,
	As5,
	B5,
	C6,
	Cs6,
	D6,
	Ds6,
	E6,
	F6,
	Fs6,
	G6,
	Gs6,
	A6,
	As6,
	B6,
	C7,
	Cs7,
	D7,
	Ds7,
	E7,
	F7,
	Fs7,
	G7,
	Gs7,
	A7,
	As7,
	B7,
	C8,
	Cs8,
	D8,
	Ds8,
	E8,
	F8,
	Fs8,
	G8,
	Gs8,
	A8,
	As8,
	B8,
	C9,
	Cs9,
	D9,
	Ds9,
	E9,
	F9,
	Fs9,
	G9,
	Gs9,
	A9,
	As9,
	B9,
	C10,
	Cs10,
	D10,
	Ds10,
	E10,
	F10,
	Fs10,
	G10
}


InputDevice[] DetectInstruments()
{
	InputDevice[] devices;

	Controller[] controllers = DetectControllers();
	Midi[] midiDevices = DetectMidiDevices();

	devices ~= controllers;

	return devices;
}
