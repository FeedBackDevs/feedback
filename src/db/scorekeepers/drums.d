module db.scorekeepers.drums;

import db.tools.log;
import db.i.scorekeeper;
import db.i.inputdevice;
import db.sequence;
import db.instrument;
import db.game;
import db.song;

import std.signals;

import fuji.fuji;

struct DrumNote
{
	@property long time() const pure nothrow		{ return pEv.time; }
	@property int tick() const pure nothrow			{ return pEv.tick; }
	@property int duration() const pure nothrow		{ return pEv.duration; }
	@property EventType event() const pure nothrow	{ return pEv.event; }

	@property int key() const pure nothrow			{ return pEv.note.key; }
	@property uint flags() const pure nothrow		{ return pEv.note.flags; }

	Event *pEv;

	bool bHit;
}

Sequence FabricateSequence(Song song, string type, Sequence from)
{
	int sourceDrums = from.variation[$-6] - '0';
	int targetDrums = type[1] - '0';

	Sequence s = new Sequence;
	s.part = from.part;
	s.variation = from.variation;
	s.difficulty = from.difficulty;
	s.difficultyMeter = from.difficultyMeter;
	s.numDoubleKicks = from.numDoubleKicks;

	int lastTom = DrumNotes.Tom3;
	int lastCymbal = DrumNotes.Hat;

	s.notes = new Event[from.notes.length];
	foreach(i, ref ev; from.notes)
	{
		s.notes[i] = ev;
		Event* pEv = &s.notes[i];

		if(pEv.event == EventType.Note)
		{
			int key = pEv.note.key;

			if(targetDrums == 6 || (targetDrums == 5 && sourceDrums != 4))
			{
				// cymbal -> hat/ride

				// crash may be assigned either hat or ride depending what was played recently
				if(key == DrumNotes.Crash)
					pEv.note.key = (lastCymbal == DrumNotes.Hat) ? DrumNotes.Ride : DrumNotes.Hat;

				// we need to remember the last cymbal played
				if(key == DrumNotes.Hat || key == DrumNotes.Ride)
					lastCymbal = key;
			}

			if(targetDrums == 5)
			{
				if(sourceDrums == 4)
				{
					// tom1 -> hat
					if(key == DrumNotes.Tom1)
						pEv.note.key = DrumNotes.Hat;
				}
				else
				{
					// tom1 -> blue
					// tom2 -> blue/green

					// yellow toms are always blue, and blue may be promoted to green if there are yellow toms recently
					if(key == DrumNotes.Tom1)
						pEv.note.key = DrumNotes.Tom2;
					else if(key == DrumNotes.Tom2)
						pEv.note.key = (lastTom == DrumNotes.Tom3) ? DrumNotes.Tom2 : DrumNotes.Tom3;

					if(key == DrumNotes.Tom1 || key == DrumNotes.Tom3)
						lastTom = key;
				}
			}

			if(targetDrums == 4)
			{
				// if the source has only 2 cymbals, we need to know where to put the ride
				if(sourceDrums == 5 || sourceDrums == 6)
				{
					string* pFallbackBlue = "drum_fallback_blue" in song.params;
					bool bFallbackBlue = pFallbackBlue && (*pFallbackBlue == "1" || icmp(*pFallbackBlue, "true"));

					// ride -> bFallbackBlue ? tom2 : tom3
					if(key == DrumNotes.Ride)
						pEv.note.key = bFallbackBlue ? DrumNotes.Tom2 : DrumNotes.Tom2;
				}
				else
				{
					// hat -> tom1
					// cymbal -> tom2
					// ride -> tim3
					if(key == DrumNotes.Hat || key == DrumNotes.Crash || key == DrumNotes.Ride)
						pEv.note.key = key + 1; // shift cymbal onto drum
				}
			}

			// TODO: flags for unavailable features need to be disabled
		}
	}

	return s;
}

class DrumsScoreKeeper : ScoreKeeper
{
	this(Sequence sequence, InputDevice input)
	{
		super(sequence, input);

		foreach(ref n; sequence.notes)
		{
			if(n.event == EventType.Note)
			{
				DrumNote note;
				note.pEv = &n;
				notes ~= note;
			}
		}
	}

	private DrumNote[] GetNext()
	{
		size_t end = offset;
		while(notes.length > end && notes[end].time == notes[offset].time)
			++end;
		return notes[offset..end];
	}

	override void Update()
	{
		long time = Game.Instance.performance.time;

		inputDevice.Update();

		long tolerance = window / 2;

		// check for missed notes?
		while(offset < notes.length && time > notes[offset].time + tolerance)
		{
			WriteLog(format("%6d missed %s: %d", notes[offset].time/1000, to!string(notes[offset].pEv.event), notes[offset].key), MFVector(1,1,1,1));
			noteMiss.emit(notes[offset].key);
			++offset;
		}

		DrumNote[] expecting = GetNext();
		if(expecting)
		{
			foreach(e; inputDevice.events)
			{
				if(e.key == DrumInput.HatPedal)
					hatPos.emit(e.velocity == 0);

				if(e.event != InputEventType.On)
					continue;

				// consider next note
				DrumNote[] next = GetNext();

				int note = e.key;

				// hat pedal down events trigger a hat hit
				if(e.key == DrumInput.HatPedal && e.event == InputEventType.On)
					note = DrumInput.Cymbal1;

				bool bDidHit = false;
				for(size_t i = offset; i < notes.length && e.timestamp >= notes[i].time - tolerance; ++i)
				{
					if(notes[i].key == note)
					{
						WriteLog(format("%6d hit %s: %d (%g)", e.timestamp/1000, to!string(e.event), note, e.velocity), MFVector(1,1,1,1));
						noteHit.emit(note, e.timestamp - notes[i].time);
						bDidHit = true;
						break;
					}
				}

				if(!bDidHit)
				{
					WriteLog(format("%6d bad %s: %d (%g)", e.timestamp/1000, to!string(e.event), note, e.velocity), MFVector(1,1,1,1));
					badNote.emit(note);
				}
			}
		}

		inputDevice.Clear();
	}

	DrumNote[] notes;
	size_t offset;

	// guitar specific
	mixin Signal!(bool) hatPos;		// (bHatUp)
}
