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


InputDevice[] DetectInstruments()
{
	InputDevice[] devices;

	Controller[] controllers = DetectControllers();
	Midi[] midiDevices = DetectMidiDevices();

	devices ~= controllers;

	return devices;
}
