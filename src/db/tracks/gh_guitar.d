module db.tracks.gh_guitar;

import db.i.notetrack;
import db.instrument;
import db.performance;
import db.renderer;

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

	void Update()
	{
	}

	void Draw(ref MFRect vp, long offset, Performer performer)
	{
		// TODO: receive a viewport where we should render

		// render GH style guitar sequence at given offset
		//...
	}
}
