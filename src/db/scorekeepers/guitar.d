module db.scorekeepers.guitar;

import db.tools.log;
import db.i.scorekeeper;
import db.inputs.inputdevice;
import db.chart.track;
import db.instrument;
import db.instrument.guitarcontroller : GuitarInput;

import std.signals;
import std.algorithm;

enum NumGuitarNotes = 5;

struct GuitarNote
{
	@property long time() const pure nothrow		{ return pEv[0].time; }
	@property int tick() const pure nothrow			{ return pEv[0].tick; }
	@property int duration() const pure nothrow		{ return pEv[0].duration; }
	@property EventType event() const pure nothrow	{ return pEv[0].event; }

	Event*[NumGuitarNotes] pEv;
	bool[NumGuitarNotes] bNoteDown;
	bool bStrike;

	bool bHit;
}

class GuitarScoreKeeper : ScoreKeeper
{
	this(Track sequence, Instrument instrument)
	{
		super(sequence, instrument);

		numNotes = cast(int)sequence.notes.count!(a => a.event == EventType.Note);
		notes = new GuitarNote[numNotes];

		GuitarNote* pGuitarNote;

		int i;
		foreach (ref n; sequence.notes.filter!(a => a.event == EventType.Note))
		{
			pGuitarNote = &notes[i++];

//			pGuitarNote.pEv = &n;
			n.pScoreKeeperData = pGuitarNote;
		}
	}

	private GuitarNote[] getNext()
	{
		size_t end = offset;
		while (notes.length > end && notes[end].time == notes[offset].time)
			++end;
		return notes[offset..end];
	}

	override void update()
	{
		instrument.update();

		long tolerance = window*1000 / 2;

		GuitarNote[] expecting = null;//GetNext();
		if (expecting)
		{
			foreach (ref e; instrument.events)
			{
				if (e.event == InputEventType.On && (e.key >= GuitarInput.Green && e.key <= GuitarInput.Orange))
					keyDown.emit(e.key);
				else if (e.event == InputEventType.Off && (e.key >= GuitarInput.Green && e.key <= GuitarInput.Orange))
					keyUp.emit(e.key);
				else if (e.key == GuitarInput.Whammy)
					whammy.emit(e.velocity);

				// consider next note
				//...

				// perhaps we should keep a running state of each input, maintaining transition times...

				WriteLog(format("%6d input %s: %d (%g)", e.timestamp/1000, to!string(e.event), e.key, e.velocity), MFVector(1,1,1,1));
			}

			// check for missed notes?

		}

		instrument.clear();
	}

	override bool wasHit(Event* pEvent)
	{
		return pEvent.pScoreKeeperData ? (cast(GuitarNote*)pEvent.pScoreKeeperData).bHit : false;
	}

	GuitarNote[] notes;
	size_t offset;

	// guitar specific
	mixin Signal!(int) keyDown;		// (key)
	mixin Signal!(int) keyUp;		// (key)
	mixin Signal!(float) whammy;	// (whammy value)
}
