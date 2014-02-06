module db.scorekeepers.guitar;

import db.i.scorekeeper;
import db.i.inputdevice;
import db.sequence;

import fuji.input;

import std.signals;

enum NumGuitarNotes = 5;

struct GuitarNote
{
	Event *pEv;
	bool[NumGuitarNotes] bNoteDown;
	bool bStrike;
	bool bHit;
}

class GuitarScoreKeeper : ScoreKeeper
{
	this(Sequence sequence, InputDevice input)
	{
		super(sequence, input);

		foreach(n; sequence.notes)
		{
			if(n.event == EventType.Note)
			{
				GuitarNote note;
				note.pEv = &n;
				notes ~= note;
			}
		}
	}

	private GuitarNote[] GetNext()
	{
		size_t end = offset;
		while(notes.length > end && notes[end].pEv.time == notes[offset].pEv.time)
			++end;
		return notes[offset..end];
	}

	override void Update()
	{
		inputDevice.Update();

		long error = tolerance / 2;

		GuitarNote[] expecting = GetNext();
		if(expecting)
		{
			foreach(e; inputDevice.events)
			{
				if(e.event == InputEventType.On && (e.key >= MFGamepadButton.GH_Green && e.key <= MFGamepadButton.GH_Orange))
					keyDown.emit(e.key - MFGamepadButton.GH_Green);
				else if(e.event == InputEventType.Off && (e.key >= MFGamepadButton.GH_Green && e.key <= MFGamepadButton.GH_Orange))
					keyUp.emit(e.key - MFGamepadButton.GH_Green);
				else if(e.key == MFGamepadButton.GH_Whammy)
					whammy.emit(e.velocity);

				// consider next note
				//...

				// perhaps we should keep a running state of each input, maintaining transition times...

			}

			// check for missed notes?

		}

		inputDevice.Clear();
	}

	GuitarNote[] notes;
	size_t offset;

	// guitar specific
	mixin Signal!(int) keyDown;		// (key)
	mixin Signal!(int) keyUp;		// (key)
	mixin Signal!(float) whammy;	// (whammy value)
}
