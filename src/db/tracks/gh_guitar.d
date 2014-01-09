module db.tracks.gh_guitar;

import db.i.notetrack;
import db.instrument;
import db.sequence;

class GHGuitar : NoteTrack
{
	@property Orientation orientation()
	{
		return Orientation.Tall;
	}

	@property InstrumentType instrumentType()
	{
		return InstrumentType.GuitarController;
	}

	void Draw(long offset, Sequence notes)
	{
		// TODO: receive a viewport where we should render

		// render GH style guitar sequence at given offset
		//...
	}
}
