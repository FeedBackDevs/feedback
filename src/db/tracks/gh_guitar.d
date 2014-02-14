module db.tracks.gh_guitar;

import fuji.materials.standard;

import db.i.notetrack;
import db.i.syncsource;
import db.instrument;
import db.performance;
import db.renderer;
import db.song;
import db.sequence;

import core.stdc.math;

class GHGuitar : NoteTrack
{
	this(Performer performer)
	{
		Song song = performer.performance.song;
		this.song = song;

		string fb = song.fretboard ? song.fretboard : "fretboard2";
		fretboard = Material(fb);
		auto params = fretboard.parameters;
		params.zread = false;
		params.minfilter["diffuse"] = MFTexFilter.Anisotropic;
		params.addressu["diffuse"] = MFTexAddressMode.Clamp;

		bar = Material("bar");
		bar.parameters.zread = false;

		edge = Material("edge");
		edge.parameters.zread = false;
	}

	@property Orientation orientation()
	{
		return Orientation.Tall;
	}

	@property InstrumentType instrumentType()
	{
		return InstrumentType.GuitarController;
	}

	@property float laneWidth()
	{
		return fretboardWidth / 5.0f;
	}

	void Update()
	{
	}

	void Draw(ref MFRect vp, long offset, Performer performer)
	{
		// HACK: horrible rendering code!
		// stolen from the old C++ feedback, but it'll do for now...

		MFView_Push();

		float aspect = vp.width / vp.height;
		//		aspect = MFClamp(0.82f, aspect, 2.0f);
		MFView_SetAspectRatio(aspect);

		// setup projection
		{
			MFView_ConfigureProjection(MFDeg2Rad!65/aspect, 1, 100);

			// setup a camera with a 3d perspective
			MFMatrix cameraMatrix;
			MFVector start = MFVector(0, 8, 3);
			MFVector dir = MFVector(0, 5, -8);
			dir = (dir-start) * (1.0f/1.777777777f);
			cameraMatrix.lookAt(start + dir*aspect, MFVector(0, 0, 5));
			MFView_SetCameraMatrix(cameraMatrix);
		}

		// capture the view stateblock
		MFStateBlock* pViewState = cast(MFStateBlock*)MFView_GetViewState();
		MFStateBlock_SetViewport(pViewState, vp);

		// calculate some variables
		float columnWidth = fretboardWidth / numLanes;
		float halfFB = fretboardWidth*0.5f;
		float ringBorder = 0.1f;

		long topTime, bottomTime;
		GetVisibleRange(offset, null, null, &bottomTime, &topTime);

		// draw the track surface
		MFMaterial_SetMaterial(fretboard);
		MFPrimitive(PrimType.TriStrip, 0);

		MFBegin(((end-start) / 4) * 2 + 2);
		MFSetColourV(MFVector.white);

		float scrollOffset = offset*scrollSpeed * (1.0f/1_000_000.0f);
		float textureOffset = fmodf(scrollOffset, fretboardRepeat);

		int a;
		for(a=start; a<=end; a+=4)
		{
			float z = cast(float)a;
			MFSetTexCoord1(1.0f, 1.0f - (z+textureOffset) / fretboardRepeat);
			MFSetPosition(halfFB, 0.0f, z);
			MFSetTexCoord1(0.0f, 1.0f - (z+textureOffset) / fretboardRepeat);
			MFSetPosition(-halfFB, 0.0f, z);
		}

		MFEnd();

		// draw the fretboard edges and bar lines
		const float barWidth = 0.2f;

		MFMaterial_SetMaterial(bar);
		MFPrimitive(PrimType.TriStrip, 0);

		MFBegin(4);
		MFSetColour(0.0f, 0.0f, 0.0f, 0.8f);
		MFSetTexCoord1(0,0);
		MFSetPosition(-halfFB, 0.0f, barWidth);
		MFSetTexCoord1(1,0);
		MFSetPosition(halfFB, 0.0f, barWidth);
		MFSetTexCoord1(0,1);
		MFSetPosition(-halfFB, 0.0f, -barWidth);
		MFSetTexCoord1(1,1);
		MFSetPosition(halfFB, 0.0f, -barWidth);
		MFEnd();

		MFMaterial_SetMaterial(edge);
		MFPrimitive(PrimType.TriStrip, 0);
		MFBegin(10 + 6*(numLanes-1));

		MFSetColour(0.0f, 0.0f, 0.0f, 0.3f);
		for(int col=1; col<numLanes; col++)
		{
			if(col > 1)
				MFSetPosition(-halfFB + columnWidth*cast(float)col - 0.02f, 0.0f, cast(float)end);

			MFSetTexCoord1(0,0);
			MFSetPosition(-halfFB + columnWidth*cast(float)col - 0.02f, 0.0f, cast(float)end);
			MFSetTexCoord1(1,0);
			MFSetPosition(-halfFB + columnWidth*cast(float)col + 0.02f, 0.0f, cast(float)end);
			MFSetTexCoord1(0,1);
			MFSetPosition(-halfFB + columnWidth*cast(float)col - 0.02f, 0.0f, cast(float)start);
			MFSetTexCoord1(1,1);
			MFSetPosition(-halfFB + columnWidth*cast(float)col + 0.02f, 0.0f, cast(float)start);

			MFSetPosition(-halfFB + columnWidth*cast(float)col + 0.02f, 0.0f, cast(float)start);
		}
		MFSetColourV(MFVector.white);
		MFSetPosition(-halfFB - 0.1f, 0.0f, cast(float)end);

		MFSetTexCoord1(0,0);
		MFSetPosition(-halfFB - 0.1f, 0.0f, cast(float)end);
		MFSetTexCoord1(1,0);
		MFSetPosition(-halfFB + 0.1f, 0.0f, cast(float)end);
		MFSetTexCoord1(0,1);
		MFSetPosition(-halfFB - 0.1f, 0.0f, cast(float)start);
		MFSetTexCoord1(1,1);
		MFSetPosition(-halfFB + 0.1f, 0.0f, cast(float)start);

		MFSetPosition(-halfFB + 0.1f, 0.0f, cast(float)start);
		MFSetPosition(halfFB - 0.1f, 0.0f, cast(float)end);

		MFSetTexCoord1(0,0);
		MFSetPosition(halfFB - 0.1f, 0.0f, cast(float)end);
		MFSetTexCoord1(1,0);
		MFSetPosition(halfFB + 0.1f, 0.0f, cast(float)end);
		MFSetTexCoord1(0,1);
		MFSetPosition(halfFB - 0.1f, 0.0f, cast(float)start);
		MFSetTexCoord1(1,1);
		MFSetPosition(halfFB + 0.1f, 0.0f, cast(float)start);

		MFEnd();

		// draw the frets....
		bool bHalfFrets = true;

		MFMaterial_SetMaterial(bar);
		MFPrimitive(PrimType.TriStrip, 0);

		int bottomTick = song.CalculateTickAtTime(bottomTime);
		int res = song.resolution;
		int ticks = bHalfFrets ? res/2 : res;
		int fretBeat = bottomTick + ticks - 1;
		fretBeat -= fretBeat % ticks;
		long fretTime = song.CalculateTimeOfTick(fretBeat);

		while(fretTime < topTime)
		{
			bool halfBeat = (fretBeat % res) != 0;
			bool bar = false;

			if(!halfBeat)
			{
				ptrdiff_t lastTS = song.sync.GetMostRecentEvent(fretBeat, EventType.TimeSignature);

				if(lastTS != -1)
					bar = ((fretBeat - song.sync[lastTS].tick) % (song.sync[lastTS].ts.numerator*res)) == 0;
				else if(fretBeat == 0)
					bar = true;
			}

			float bw = bar ? barWidth : barWidth*0.5f;
			MFBegin(4);

			float position = (fretTime - offset)*scrollSpeed * (1.0f/1_000_000.0f);

			if(!halfBeat)
				MFSetColourV(MFVector.white);
			else
			{
				MFVector faint = MFVector(1,1,1,0.3f);
				MFSetColourV(faint);
			}
			MFSetTexCoord1(0,0);
			MFSetPosition(-halfFB, 0.0f, position + bw);
			MFSetTexCoord1(1,0);
			MFSetPosition(halfFB, 0.0f, position + bw);
			MFSetTexCoord1(0,1);
			MFSetPosition(-halfFB, 0.0f, position + -bw);
			MFSetTexCoord1(1,1);
			MFSetPosition(halfFB, 0.0f, position + -bw);

			MFEnd();

			fretBeat += ticks;
			fretTime = song.CalculateTimeOfTick(fretBeat);
		}

		// draw the notes
		auto notes = performer.sequence.notes.BetweenTimes(bottomTime, topTime);
		__gshared immutable MFVector colours[5] = [ MFVector.green, MFVector.red, MFVector(1,1,0,1), MFVector.blue, MFVector(1,0.5,0,1) ];
		foreach(ref e; notes)
		{
			if(e.event != EventType.Note)
				continue;

			// HACK: don't render notes for which we have no lanes!
			if(e.note.key > numLanes)
				continue;

			MFVector pos = GetPosForTime(offset, e.time, Lane(e.note.key));

			if(e.duration > 0)
			{
				MFVector end = GetPosForTick(offset, e.tick + e.duration, Lane(e.note.key));

				auto b1 = MFVector(pos.x - columnWidth*0.1f, 0, end.z);
				auto b2 = MFVector(pos.x + columnWidth*0.1f, columnWidth*0.05f, pos.z);
				MFPrimitive_DrawBox(b1, b2, colours[e.note.key], MFMatrix.identity, false);
			}

			auto b1 = MFVector(pos.x - columnWidth*0.3f, 0, pos.z - columnWidth*0.3f);
			auto b2 = MFVector(pos.x + columnWidth*0.3f, columnWidth*0.2f, pos.z + columnWidth*0.3f);
			MFPrimitive_DrawBox(b1, b2, colours[e.note.key], MFMatrix.identity, false);
		}


		// render some overlay stuff
		MFRect rect = MFRect(0, 0, 1920, 1080);
		MFView_SetOrtho(&rect);

		auto songEvents = song.events.BetweenTimes(bottomTime, topTime);
		foreach(ref e; songEvents)
		{
			if(e.event != EventType.Event)
				continue;

			MFVector pos = GetPosForTime(offset, e.time, RelativePosition.Right);

			MFVector r;
			MFView_TransformPoint3DTo2D(pos, &r);
			MFFont_DrawTextAnchored(MFFont_GetDebugFont(), e.text.toStringz, r, MFFontJustify.Bottom_Left, 1920.0f, 30.0f, MFVector.white);
		}

		auto trackEvents = performer.sequence.notes.BetweenTimes(bottomTime, topTime);
		foreach(ref e; trackEvents)
		{
			if(e.event != EventType.Event)
				continue;

			MFVector pos = GetPosForTime(offset, e.time, RelativePosition.Left);

			MFVector r;
			MFView_TransformPoint3DTo2D(pos, &r);
			MFFont_DrawTextAnchored(MFFont_GetDebugFont(), e.text.toStringz, r, MFFontJustify.Bottom_Right, 1920.0f, 30.0f, MFVector.white);
		}

		MFView_Pop();
	}

	MFVector GetPosForTick(long offset, int tick, RelativePosition pos)
	{
		return GetPosForTime(offset, song.CalculateTimeOfTick(tick), pos);
	}

	MFVector GetPosForTime(long offset, long time, RelativePosition pos)
	{
		MFVector p;
		p.z = (time-offset)*scrollSpeed*(1.0f/1_000_000.0f);
		p.x = GetX(pos);
		return p;
	}

	void GetVisibleRange(long offset, int* pStartTick, int* pEndTick, long* pStartTime, long* pEndTime)
	{
		if(pStartTime || pStartTick)
		{
			long startTime = offset + cast(long)start*1_000_000/scrollSpeed;
			if(pStartTime)
				*pStartTime = startTime;
			if(pStartTick)
				*pStartTick = song.CalculateTickAtTime(startTime);
		}
		if(pEndTime || pEndTick)
		{
			long endTime = offset + cast(long)end*1_000_000/scrollSpeed;
			if(pEndTime)
				*pEndTime = endTime;
			if(pEndTick)
				*pEndTick = song.CalculateTickAtTime(endTime);
		}
	}

	Song song;

	Material fretboard;
	Material bar;
	Material edge;

private:
	float GetX(RelativePosition pos)
	{
		switch(pos) with(RelativePosition)
		{
			case Center:
				return 0;
			case Left:
				return -fretboardWidth*0.5f;
			case Right:
				return fretboardWidth*0.5f;
			case Top:
			case Bottom:
				assert(false, "GH guitar is rendered vertically.");
			default:
				int lane = pos - Lane;
				assert(lane >= 0 && lane < numLanes, "Invalid lane!");

				float laneWidth = fretboardWidth / numLanes;
				return -fretboardWidth*0.5f + laneWidth*(cast(float)lane + 0.5f); // return the lane center?
		}
	}

	// some constants for the fretboard
	int numLanes = 5;

	int start = -4;
	int end = 60;
	int fadeStart = end.init - 10;

	int scrollSpeed = 12;

	float fretboardRepeat = 15.0f;
	float fretboardWidth = 7.0f;
}
