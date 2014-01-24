module db.instrument;

import db.i.inputdevice;
import db.inputs.controller;


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
enum GuitarNotes
{
	Green,
	Red,
	Yellow,
	Blue,
	Orange,
	Open
}

enum GuitarProperties
{
	HasSolo,
	HasSlider
}

enum GuitarNoteFlags
{
	HOPO,	// hammer-on/pull-off
	Tap		// tap note
}

// drums
enum DrumNotes
{				// RB kit		GH kit
	Snare,		//   R			  R
	Tom1,		//   Y			  B
	Tom2,		//   B			  B/G?
	Tom3,		//   G			  G
	Hat,		//   Y			  Y
	Spash,		//   B			  Y/O?
	Crash,		//   B/G?		  Y/O?
	Ride,		//   G			  O
	Kick,
}

enum DrumNoteFlags
{
	DoubleKick,	// double kick notes are hidden in single-kick mode
	OpenHat		// interesting if drum kit has a hat pedal
}

// dance mat
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

enum DanceProperties
{
	HasDancePads,	// Up, Down, Left, Right
	HasSoloPads,	// UpLeft, UpRight
	HasPumpPads		// UpLeft, UpRight, DownLeft, DownRight, Center
}

InputDevice[] DetectInstruments()
{
	InputDevice[] devices;

	Controller[] controllers = DetectControllers();

	devices ~= controllers;

	return devices;
}
