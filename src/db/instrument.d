module db.instrument;

// list of instruments i've encountered in various music games
// obviously, many of these would not be supported (... at first?) ;)
// options to keep in mind when writing code or making UI choices
enum Instrument
{
	LeadGuitar,		// lead guiutar
	RythmGuitar,	// rhythm guitar
	Bass,			// bass guitar
	Drums,			// drums
	Vox,			// lead vocals
	Vox2,			// secondary/backing vocals
	Keys,			// keyboard
	ProGuitar,		// pro guitar
	DJ,				// DJ hero

	// Bemani games
	Dance,			// dance mat
	DanceDouble,	// double dance mat
	DanceSolo,		// dance mat
	Pump,			// pump it up
	Beatmania,		// beatmania controller

	// silly (fun!) shit
	Conga,			// ie, Donkey Conga
	Taiko,			// http://www.screwattack.com/sites/default/files/image/images/News/2012/0402/261_560635649740_23911393_36125747_3873_n.jpg

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

enum GuitarNoteFlags
{
	HOPO,	// hammer-on/pull-off
	Tap,	// tap note
	Solo,	// rock band solo keys
	Slide	// guitar hero slider
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
