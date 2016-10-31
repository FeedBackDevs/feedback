module db.i.notetrack;

import db.i.syncsource;
import db.instrument;
import db.game.performance;

import fuji.types;
import fuji.vector;

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

enum RelativePosition
{
	Center,
	Left,	// for vertical tracks
	Right,	// for vertical tracks
	Top,	// for horizontal tracks
	Bottom,	// for horizontal tracks

	Lane,	// lane center - add the lane number (or use Lane(n))
}

RelativePosition Lane(int i) pure nothrow
{
	return cast(RelativePosition)(RelativePosition.Lane + i);
}

abstract class NoteTrack
{
	this(Performer performer)
	{
		this.performer = performer;
	}

	@property Orientation orientation();
	@property string instrumentType();

	@property float laneWidth();

	void Update();
	void Draw(ref MFRect vp, long offset);
	void DrawUI(ref MFRect vp);

	MFVector GetPosForTick(long offset, int tick, RelativePosition pos);	// get a world position for the tick
	MFVector GetPosForTime(long offset, long time, RelativePosition pos);	// get a world position for the time
	void GetVisibleRange(long offset, int* pStartTick, int* pEndTick, long* pStartTime, long* pEndTime);	// get the range displayed by the track

	Performer performer;
}
