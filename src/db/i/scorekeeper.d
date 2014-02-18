module db.i.scorekeeper;

import db.i.inputdevice;
import db.i.syncsource;
import db.sequence;

import std.signals;

abstract class ScoreKeeper
{
	this(Sequence sequence, InputDevice input)
	{
		this.sequence = sequence;
		this.inputDevice = input;
	}

	void Begin(SyncSource sync)
	{
		inputDevice.Begin(sync);
	}

	void Update();

	bool WasHit(Event* pEvent);

	@property long averageError() { return numErrorSamples ? cumulativeError / numErrorSamples : 0; }
	@property int hitPercentage() { return numNotes ? numHits*100 / numNotes : 0; }

	Sequence sequence;
	InputDevice inputDevice;

	int numNotes;
	int numHits;

	int score;
	int combo;
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
