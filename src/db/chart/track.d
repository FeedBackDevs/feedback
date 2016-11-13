module db.chart.track;

public import db.chart.event;

enum Difficulty
{
	Beginner,
	Easy,
	Medium,
	Hard,
	Expert
}

class Track
{
	string part;
	string variationType;
	string variationName;
	string difficultyName;	// different games have different terminology for difficulties
	Difficulty difficulty;
	int difficultyMeter;	// from 1 - 10

	Event[] notes;

	// instrument specific parameters
	int numDoubleKicks; // keep a counter so we know if the drums have double kicks or not
}
