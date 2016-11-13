module db.scorekeepers.drums;

import db.tools.log;
import db.i.scorekeeper;
import db.inputs.inputdevice;
import db.chart.track;
import db.instrument;
import db.instrument.drums : DrumNotes, DrumInput;
import db.game;
import db.chart;

import std.signals;
import std.algorithm;

import fuji.fuji;

struct DrumNote
{
	@property long time() const pure nothrow		{ return pEv.time; }
	@property int tick() const pure nothrow			{ return pEv.tick; }
	@property int duration() const pure nothrow		{ return pEv.duration; }
	@property EventType event() const pure nothrow	{ return pEv.event; }

	@property int key() const pure nothrow			{ return pEv.note.key; }
	@property uint flags() const pure nothrow		{ return pEv.flags; }

	Event* pEv;

	bool bHit;
}

Track fabricateTrack(Chart song, string type, Track from)
{
	int sourceDrums = from.variationType[0] - '0';
	int targetDrums = type[0] - '0';

	Track s = new Track;
	s.part = from.part;
	s.variationType = type;
	s.variationName = from.variationName;
	s.difficulty = from.difficulty;
	s.difficultyMeter = from.difficultyMeter;
	s.numDoubleKicks = from.numDoubleKicks;

	string* pFallbackBlue = "drum_fallback_blue" in song.params;
	bool bFallbackBlue = pFallbackBlue && (*pFallbackBlue == "1" || !icmp(*pFallbackBlue, "true"));

	string* pOrangeIsCrash = "orange_is_crash" in song.params;
	bool bOrangeIsCrash = pOrangeIsCrash && (*pOrangeIsCrash == "1" || !icmp(*pOrangeIsCrash, "true"));

	int lastTom = DrumNotes.Tom3;
	int lastCymbal = DrumNotes.Hat;

	s.notes = new Event[from.notes.length];
	foreach (i, ref ev; from.notes)
	{
		s.notes[i] = ev;
		Event* pEv = &s.notes[i];

//		if (0)
		if (pEv.event == EventType.Note)
		{
			int key = pEv.note.key;

			if (targetDrums == 6 || (targetDrums == 5 && sourceDrums != 4))
			{
				if (bOrangeIsCrash)
				{
					// cymbal -> ride
					// ride -> hat/ride

					if (key == DrumNotes.Crash)
						pEv.note.key = DrumNotes.Ride;

					// crash may be assigned either hat or ride depending what was played recently
					if (key == DrumNotes.Ride)
						pEv.note.key = (lastCymbal == DrumNotes.Hat) ? DrumNotes.Ride : DrumNotes.Hat;

					// we need to remember the last cymbal played
					if (key == DrumNotes.Hat || key == DrumNotes.Crash)
						lastCymbal = key;
				}
				else
				{
					// cymbal -> hat/ride

					// crash may be assigned either hat or ride depending what was played recently
					if (key == DrumNotes.Crash)
						pEv.note.key = (lastCymbal == DrumNotes.Hat) ? DrumNotes.Ride : DrumNotes.Hat;

					// we need to remember the last cymbal played
					if (key == DrumNotes.Hat || key == DrumNotes.Ride)
						lastCymbal = key;
				}
			}

			if (targetDrums == 5)
			{
				if (sourceDrums == 4)
				{
					// tom1 -> hat
					if (key == DrumNotes.Tom1)
						pEv.note.key = DrumNotes.Hat;
				}
				else
				{
					// tom1 -> blue
					// tom2 -> blue/green

					// yellow toms are always blue, and blue may be promoted to green if there are yellow toms recently
					if (key == DrumNotes.Tom1)
						pEv.note.key = DrumNotes.Tom2;
					else if (key == DrumNotes.Tom2)
						pEv.note.key = (lastTom == DrumNotes.Tom3) ? DrumNotes.Tom2 : DrumNotes.Tom3;

					if (key == DrumNotes.Tom1 || key == DrumNotes.Tom3)
						lastTom = key;
				}
			}

			if (targetDrums < 8)
			{
				if (key == DrumNotes.Hat)
					pEv.note.key = DrumNotes.Crash;
			}

			if (targetDrums == 4)
			{
				// if the source has only 2 cymbals, we need to know where to put the ride
				if (sourceDrums == 5 || sourceDrums == 6)
				{
					// ride -> bFallbackBlue ? tom2 : tom3
					if (key == DrumNotes.Ride)
						pEv.note.key = bFallbackBlue ? DrumNotes.Tom2 : DrumNotes.Tom3;
				}
				else
				{
					// hat -> tom1
					// crash/splash -> tom2
					// ride -> tom3
					switch (key)
					{
						case DrumNotes.Hat: pEv.note.key = DrumNotes.Tom1; break;
						case DrumNotes.Crash: pEv.note.key = DrumNotes.Tom2; break;
						case DrumNotes.Splash: pEv.note.key = DrumNotes.Tom2; break;
						case DrumNotes.Ride: pEv.note.key = DrumNotes.Tom3; break;
						default:
					}
				}
			}

			// TODO: flags for unavailable features need to be disabled
		}
	}

	return s;
}

class DrumsScoreKeeper : ScoreKeeper
{
	this(Track sequence, Instrument instrument)
	{
		super(sequence, instrument);

		numNotes = cast(int)sequence.notes.count!(a => a.event == EventType.Note);
		notes = new DrumNote[numNotes];

		int i;
		foreach (ref n; sequence.notes.filter!(a => a.event == EventType.Note))
		{
			DrumNote* pDrumNote = &notes[i++];

			pDrumNote.pEv = &n;
			n.pScoreKeeperData = pDrumNote;
		}
	}

	private DrumNote[] getNext()
	{
		size_t end = offset;
		while (notes.length > end && notes[end].time == notes[offset].time)
			++end;
		return notes[offset..end];
	}

	override void update()
	{
		long audioLatency = Game.instance.settings.audioLatency*1_000;
		long time = instrument.inputTime - audioLatency;

		instrument.update();

		long tolerance = window*1000 / 2;

		// check for missed notes?
		while (offset < notes.length)
		{
			if (notes[offset].bHit)
				++offset;
			else if (time > notes[offset].time + tolerance)
			{
//				WriteLog(format("%6d missed: %d", notes[offset].time/1000, notes[offset].key), MFVector(1,1,1,1));

				int oldCombo = combo;
				combo = 0;
				multiplier = 1;

				noteMiss.emit(notes[offset].key);
				if (oldCombo > 1)
					lostCombo.emit();

				++offset;
			}
			else
				break;
		}

		foreach (ref e; instrument.events)
		{
//			if (e.key == DrumInput.HatPedal)
//				hatPos.emit(e.velocity == 0);

			if (e.event != InputEventType.On)
				continue;

			// adjust timestamp to compensate for audio latency
			long timestamp = e.timestamp - audioLatency;

//			WriteLog(format("%6d input: %d (%g)", timestamp/1000, e.key, e.velocity), MFVector(1,1,1,1));

			// consider next note
			DrumNote[] next = getNext();

			int note = e.key;

			// hat pedal down events trigger a hat hit
//			if (e.key == DrumInput.HatPedal && e.event == InputEventType.On)
//				note = DrumInput.Cymbal1;

			bool bDidHit = false;
			for (size_t i = offset; i < notes.length && timestamp >= notes[i].time - tolerance; ++i)
			{
				if (notes[i].bHit)
					continue;

				if (notes[i].key == note)
				{
					long error = timestamp - notes[i].time;
					cumulativeError += error;
					++numErrorSamples;

					WriteLog(format("%6d hit: %d (%g) - %d", notes[i].time/1000, note, e.velocity, error/1000), MFVector(1,1,1,1));

					notes[i].bHit = true;

					// update counters
					++numHits;
					++combo;
					longestCombo = max(combo, longestCombo);

					int oldMultiplier = multiplier;
					multiplier = min(1 + combo/10, 4);
					if (bStarPowerActive)
						multiplier *= 2;

					// score note
					score += 25*multiplier;

					// emit sognals
					noteHit.emit(note, error);
					if (multiplier > oldMultiplier)
						multiplierIncrease.emit();

					bDidHit = true;
					if (i == offset)
						++offset;
					break;
				}
			}
			if (!bDidHit)
			{
				WriteLog(format("%6d bad: %d (%g)", timestamp/1000, note, e.velocity), MFVector(1,1,1,1));

				int oldCombo = combo;
				combo = 0;
				multiplier = 1;

				badNote.emit(note);
				if (oldCombo > 1)
					lostCombo.emit();
			}
		}

		instrument.clear();
	}

	override bool wasHit(Event* pEvent)
	{
		return pEvent.pScoreKeeperData ? (cast(DrumNote*)pEvent.pScoreKeeperData).bHit : false;
	}

	DrumNote[] notes;
	size_t offset;

	// drum specific
//	mixin Signal!(bool) hatPos;		// (bHatUp)
}
