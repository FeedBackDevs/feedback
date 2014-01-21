module db.i.notetrack;

import db.i.syncsource;
import db.instrument;
import db.performance;

import fuji.types;

// screen real-estate will be dynamically divided depending on the number of players, and the instruments in the game
// well written note tracks should attempt to fill the screen space given
// tracks should suggest their preferred dimensions so the screen-subdivision can do a good job
enum Orientation
{
	DontCare,	// track is very flexible
	Square,		// track is more-or-less square
	Wide,		// horizontal with reasonable height
	VeryWide,	// horizontal, very little height (ie, the text + worm for vocal tracks)
	Tall,		// vertical with reasonable width (ie, typical guitar/drums/dance/etc)
	VeryTall,	// vertical, very narrow
	Huge		// track needs a LOT of screen space (ie, rocksmith guitar track)
}

interface NoteTrack
{
	@property Orientation orientation();
	@property InstrumentType instrumentType();

	void Update();
	void Draw(ref MFRect vp, long offset, Performer performer);
}
