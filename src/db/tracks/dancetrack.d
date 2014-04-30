module db.tracks.dancetrack;

import fuji.fuji;
import fuji.materials.standard;

import db.i.notetrack;
import db.i.scorekeeper;
import db.i.inputdevice;
import db.i.syncsource;
import db.instrument;
import db.performance;
import db.renderer;
import db.song;
import db.sequence;

import core.stdc.math;
import std.string;

class DanceTrack : NoteTrack
{
	this(Performer performer)
	{
		super(performer);

		Song song = performer.performance.song;
		this.song = song;

		string fb = song.fretboard ? song.fretboard : "track0";
		track = Material(fb);
		auto params = track.parameters;
		params.zread = false;
		params.minfilter["diffuse"] = MFTexFilter.Anisotropic;
		params.addressu["diffuse"] = MFTexAddressMode.Clamp;

		bar = Material("bar");
		bar.parameters.zread = false;

		edge = Material("edge");
		edge.parameters.zread = false;

		switch(performer.sequence.variation)
		{
			case "dance-single":	numLanes = 4;  laneMap = [ 0,1,2,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 ];	break;
			case "dance-double":	numLanes = 8;  laneMap = [ 0,1,2,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,4,5,6,7,-1,-1,-1,-1,-1,-1,-1 ];	break;
			case "dance-couple":	numLanes = 8;  laneMap = [ 0,1,2,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,4,5,6,7,-1,-1,-1,-1,-1,-1,-1 ];	break;
			case "dance-solo":		numLanes = 6;  laneMap = [ 0,2,3,5,1,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 ];	break;
			case "pump-single":		numLanes = 5;  laneMap = [ -1,-1,-1,-1,1,3,0,4,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 ];	break;
			case "pump-double":		numLanes = 10; laneMap = [ -1,-1,-1,-1,1,3,0,4,2,-1,-1,-1,-1,-1,-1,-1,-1,6,8,5,9,7,-1,-1 ];	break;
			case "pump-couple":		numLanes = 10; laneMap = [ -1,-1,-1,-1,1,3,0,4,2,-1,-1,-1,-1,-1,-1,-1,-1,6,8,5,9,7,-1,-1 ];	break;
			case "ez2-single":		numLanes = 5;  laneMap = [ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 ];	break;
			case "ez2-double":		numLanes = 10; laneMap = [ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 ];	break;
			case "ez2-real":		numLanes = 7;  laneMap = [ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 ];	break;
			case "para-single":		numLanes = 5;  laneMap = [ 0,-1,2,4,1,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 ];	break;
			default: break;
		}

//			__gshared immutable int[5] mapEz2Single		= [ UpLeft,LeftHand,Down,RightHand,UpRight ];
//			__gshared immutable int[10] mapEz2Double	= [ UpLeft,LeftHand,Down,RightHand,UpRight,UpLeft2,LeftHand2,Down2,RightHand2,UpRight2 ];
//			__gshared immutable int[7] mapEz2Real		= [ UpLeft,LeftHandBelow,LeftHand,Down,RightHand,RightHandBelow,UpRight ];


		// we could remap the lanes from effects and options if we wanted to
		//...
	}

	override @property Orientation orientation()
	{
		return Orientation.Tall;
	}

	override @property InstrumentType instrumentType()
	{
		return InstrumentType.Dance;
	}

	override @property float laneWidth()
	{
		return trackWidth / numLanes;
	}

	override void Update()
	{
	}

	override void Draw(ref MFRect vp, long offset)
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
		float columnWidth = trackWidth / numLanes;
		float halfFB = trackWidth*0.5f;
		float ringBorder = 0.1f;

		long topTime, bottomTime;
		GetVisibleRange(offset, null, null, &bottomTime, &topTime);

		// draw the track surface
		track.setCurrent();
		MFPrimitive(PrimType.TriStrip, 0);

		MFBegin(((end-start) / 4) * 2 + 2);
		MFSetColourV(MFVector.white);

		float scrollOffset = offset*scrollSpeed * (1.0f/1_000_000.0f);
		float textureOffset = fmodf(scrollOffset, trackRepeat);

		int a;
		for(a=start; a<=end; a+=4)
		{
			float z = cast(float)a;
			MFSetTexCoord1(1.0f, 1.0f - (z+textureOffset) / trackRepeat);
			MFSetPosition(halfFB, 0.0f, z);
			MFSetTexCoord1(0.0f, 1.0f - (z+textureOffset) / trackRepeat);
			MFSetPosition(-halfFB, 0.0f, z);
		}

		MFEnd();

		// draw the track edges and bar lines
		const float barWidth = 0.2f;

		bar.setCurrent();
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

		edge.setCurrent();
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

		bar.setCurrent();
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

		foreach(ref e; notes)
		{
			if(e.event != EventType.Note)
				continue;

			// if it was hit, we don't need to render it
			if(performer.scoreKeeper.WasHit(&e))
				continue;

			int key = laneMap[e.note.key];

			// HACK: don't render notes for which we have no lanes!
			if(key == -1)
				continue;
 
			MFVector pos;
			float noteWidth, noteDepth, noteHeight;

			pos = GetPosForTime(offset, e.time, Lane(key));
			noteWidth = columnWidth*0.3f;
			noteDepth = columnWidth*0.3f;
			noteHeight = columnWidth*0.2f;

			if(e.duration > 0)
			{
				MFVector end = GetPosForTick(offset, e.tick + e.duration, RelativePosition.Center);

				auto b1 = MFVector(pos.x - noteWidth*0.3f, 0, end.z);
				auto b2 = MFVector(pos.x + noteWidth*0.3f, noteHeight*0.05f, pos.z);
				MFPrimitive_DrawBox(b1, b2, MFVector.green, MFMatrix.identity, false);
			}

			auto b1 = MFVector(pos.x - noteWidth, 0, pos.z - noteDepth);
			auto b2 = MFVector(pos.x + noteWidth, noteHeight, pos.z + noteDepth);
			MFPrimitive_DrawBox(b1, b2, MFVector.green, MFMatrix.identity, false);
		}

/*
		struct vertex
		{
			@(MFVertexElementType.Position)
				MFVertexFloat3 pos;
		}

		float[] arr = [ 1,2,3,4,5,6 ];

		vertex[] verts =
		[
			vertex(MFVertexFloat3(0,0,0)),
			vertex(MFVertexFloat3(1,0,0)),
			vertex(MFVertexFloat3(2,0,0))
		];

		MFVertexFloat3 v = arr[0..3];

		auto vb = VertexBuffer!vertex(100, MFVertexBufferType.Static, "Hello!");
*/

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

		int tick = song.CalculateTickAtTime(offset);
		MFFont_DrawText2(null, 1920 - 200, 10, 20, MFVector.yellow, ("Time: " ~ to!string(offset/1_000_000.0)).toStringz);
		MFFont_DrawText2(null, 1920 - 200, 30, 20, MFVector.orange, ("Offset: " ~ to!string(tick/cast(double)song.resolution)).toStringz);

		MFView_Pop();
	}

	override void DrawUI(ref MFRect vp)
	{
		// write average error
		MFFont_DrawText2(null, 10, 10, 20, MFVector.white, ("Error: " ~ to!string(performer.scoreKeeper.averageError/1000)).toStringz);

		MFFont_DrawText2(null, 10, 100, 50, MFVector.yellow, ("Score: " ~ to!string(performer.scoreKeeper.score)).toStringz);

		MFFont_DrawText2(null, 10, 180, 50, MFVector.red, ("Combo: " ~ to!string(performer.scoreKeeper.combo)).toStringz);
		MFFont_DrawText2(null, 10, 230, 70, MFVector.magenta, ("Multiplier: " ~ to!string(performer.scoreKeeper.multiplier) ~ "x").toStringz);
	}

	override MFVector GetPosForTick(long offset, int tick, RelativePosition pos)
	{
		return GetPosForTime(offset, song.CalculateTimeOfTick(tick), pos);
	}

	override MFVector GetPosForTime(long offset, long time, RelativePosition pos)
	{
		MFVector p;
		p.z = (time-offset)*scrollSpeed*(1.0f/1_000_000.0f);
		p.x = GetX(pos);
		return p;
	}

	override void GetVisibleRange(long offset, int* pStartTick, int* pEndTick, long* pStartTime, long* pEndTime)
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

	Material track;
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
				return -trackWidth*0.5f;
			case Right:
				return trackWidth*0.5f;
			case Top:
			case Bottom:
				assert(false, "Dance tracks are rendered vertically.");
			default:
				int lane = pos - Lane;
				assert(lane >= 0 && lane < numLanes, "Invalid lane!");

				float laneWidth = trackWidth / numLanes;
				return -trackWidth*0.5f + laneWidth*(cast(float)lane + 0.5f); // return the lane center?
		}
	}

	// some constants for the track
	int numLanes;
	int[] laneMap;

	int start = -4;
	int end = 60;
	int fadeStart = end.init - 10;

	int scrollSpeed = 12;

	float trackRepeat = 15.0f;
	float trackWidth = 5.0f;
}