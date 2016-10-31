module db.chart.track;

public import db.chart.event;

class Track
{
	string part;
	string variation;
	string difficulty;
	int difficultyMeter;	// from 1 - 10

	Event[] notes;

	// instrument specific parameters
	int numDoubleKicks; // keep a counter so we know if the drums have double kicks or not
}
