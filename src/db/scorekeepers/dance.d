module db.scorekeepers.dance;

import db.tools.log;
import db.i.scorekeeper;
import db.inputs.inputdevice;
import db.chart.track;
import db.instrument;
import db.game;

import std.signals;
import std.algorithm;

import fuji.fuji;

struct DanceNote
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

class DanceScoreKeeper : ScoreKeeper
{
	this(Track sequence, Instrument instrument)
	{
		super(sequence, instrument);

		numNotes = cast(int)sequence.notes.count!(a => a.event == EventType.Note);
		notes = new DanceNote[numNotes];

		int i;
		foreach (ref n; sequence.notes.filter!(a => a.event == EventType.Note))
		{
			DanceNote* pDanceNote = &notes[i++];

			pDanceNote.pEv = &n;
			n.pScoreKeeperData = pDanceNote;
		}
	}

	private DanceNote[] getNext()
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
				WriteLog(format("%6d missed: %d", notes[offset].time/1000, notes[offset].key), MFVector(1,1,1,1));

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
			if (e.event != InputEventType.On)
				continue;

			// adjust timestamp to compensate for audio latency
			long timestamp = e.timestamp - audioLatency;

//			WriteLog(format("%6d input: %d (%g)", timestamp/1000, e.key, e.velocity), MFVector(1,1,1,1));

			// consider next note
			DanceNote[] next = getNext();

			int note = e.key;

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
		return pEvent.pScoreKeeperData ? (cast(DanceNote*)pEvent.pScoreKeeperData).bHit : false;
	}

	DanceNote[] notes;
	size_t offset;
}
