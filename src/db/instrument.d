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
	HOPO,			// hammer-on/pull-off
	Tap,			// tap note

	// these are only for 'real' guitar
	Slide,			// slide
	Mute,			// palm muting
	Harm,			// harmonic
	ArtificialHarm	// artificial harmonic
}


// drums
enum DrumFeatures
{
	Has4Drums,
	HasAnyCymbals,
	Has2Cymbals,
	Has3Cymbals,
	HasHiHat,
	HasHiHatPedal,
	HasRims,
	HasCymbalBells,
	HasVelocity
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
	Hat,		//   Y			  Y
	Snare,		//   R			  R
	Crash,		//   B			  Y(/O?)
	Tom1,		//   Y			  B
	Tom2,		//   B			  B(/G?)
	Splash,		//   B/G?		  (Y?/)O
	Tom3,		//   G			  G
	Ride,		//   G			  O
	Kick,
//	Cowbell,	// cowbell or tambourine
}

enum DrumNoteFlags
{
	DoubleKick,	// double kick notes are hidden in single-kick mode
	OpenHat,	// interesting if drum kit has a hat pedal
	RimShot,	// if drums have rims
	CymbalBell,	// if cymbals have zones
}

enum DrumAnimation
{
	Kick_RF, // 24 C0 = Kick hit w/RF
	HatUp_LF, // 25 C#0 = Hi-Hat pedal up (hat open) w/LF. The hat will stay open for the duration of the note. The default is pedal down (hat closed).
	Snare_LH, // 26 D0 = Snare hit w/LH
	Snare_RH, // 27 D#0 = Snare hit w/RH
	Snare_Soft_LH, // 28 (E0) is a soft snare hit with the left hand
	Snare_Soft_RH, // 29 (F0) is a soft snare hit with the right hand
	Hat_LH, // 30 F#0 = Hi-Hat hit w/LH
	Hat_RH, // 31 G0 = Hi-Hat hit w/RH
	Percussion_RH, // 32 G#0 = Percussion w/ RH
	Unknown, // NOTE: 33 is some unknown event?
	Crash1_LH, // 34 A#0 = Crash1 hard hit w/LH
	Crash1_Soft_LH, // 35 B0 = Crash1 soft hit w/LH
	Crash1_RH, // 36 C1 = Crash1 hard hit w/RH
	Crash1_Soft_RH, // 37 C#1 = Crash1 (near Hi-Hat) soft hit w/RH
	Crash2_RH, // 38 D1 = Crash2 hard hit w/RH
	Crash2_Soft_RH, // 39 D#1 = Crash2 (near Ride Cym) soft hit w/RH
	Crash1Choke, // 40 E1 = Crash1 Choke (hit w/RH, choke w/LH)
	Crash2Choke, // 41 F1 = Crash2 Choke (hit w/RH, choke w/LH)
	Ride_RH, // 42 F#1 = Ride Cym hit w/RH
	Ride_LH, // 43 (G1) is a ride hit w/LH
	Crash2_LH, // 44 (G#1) is a hit on crash 2 w/LH
	Crash2_Soft_LH, // 45 (A1) is a soft hit on crash 2 w/LH
	Tom1_LH, // 46 A#1 = Tom1 hit w/LH
	Tom1_RH, // 47 B1 = Tom1 hit w/RH
	Tom2_LH, // 48 C2 = Tom2 hit w/LH
	Tom2_RH, // 49 C#2 = Tom2 hit w/RH
	FloorTom_LH, // 50 D2 = Floor Tom hit w/LH
	FloorTom_RH // 51 D#2 = Floor Tom hit w/RH
}

// keyboard


// dance mat
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
	RightHand2
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


InputDevice[] detectInstruments()
{
	InputDevice[] devices;

	Controller[] controllers = detectControllers();
	Midi[] midiDevices = detectMidiDevices();

	devices ~= controllers;
	devices ~= midiDevices;

	return devices;
}
