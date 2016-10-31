module db.i.scorekeeper;

import db.instrument : Instrument;
import db.i.syncsource;
import db.chart.track;

import std.signals;

abstract class ScoreKeeper
{
	this(Track track, Instrument instrument)
	{
		this.track = track;
		this.instrument = instrument;
	}

	void Begin(SyncSource sync)
	{
		instrument.Begin(sync);
	}

	void Update();

	bool WasHit(Event* pEvent);

	@property long averageError() { return numErrorSamples ? cumulativeError / numErrorSamples : 0; }
	@property int hitPercentage() { return numNotes ? numHits*100 / numNotes : 0; }

	Track track;
	Instrument instrument;

	int numNotes;
	int numHits;

	int score;
	int combo;
	int longestCombo;
	int multiplier = 1;

	float starPower;
	bool bStarPowerActive;

	long cumulativeError;
	int numErrorSamples;

	long window = 200; // in milliseconds

	// shared
	mixin Signal!(int, long) noteHit;	// (note, precision) precision is microseconds from the precise note time
	mixin Signal!(int) noteMiss;		// (note)
	mixin Signal!(int) badNote;			// (note)
	mixin Signal!() lostCombo;			// (note)
	mixin Signal!() multiplierIncrease;	// (note)
	mixin Signal!() gainBoost;			// ()
	mixin Signal!() triggerBoost;		// ()
}
