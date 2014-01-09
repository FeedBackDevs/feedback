module db.tracks.gh_drums;

import db.i.notetrack;
import db.instrument;
import db.sequence;

class GHDrums : NoteTrack
{
	@property Orientation orientation()
	{
		return Orientation.Tall;
	}

	@property InstrumentType instrumentType()
	{
		return InstrumentType.Drums;
	}

	void Draw(long offset, Sequence notes)
	{
		// TODO: receive a viewport where we should render

		// render GH style guitar sequence at given offset
		//...
	}
}
