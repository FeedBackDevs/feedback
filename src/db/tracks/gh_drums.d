module db.tracks.gh_drums;

import fuji.materials.standard;

import db.i.notetrack;
import db.i.syncsource;
import db.instrument;
import db.performance;
import db.renderer;
import db.song;

import core.stdc.math;

class GHDrums : NoteTrack
{
	this(Song song)
	{
//		asm { int 3; }

		string fb = song.fretboard ? song.fretboard : "fretboard0";
		fretboard = Material(fb);
		fretboard.parameters.zread = false;

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
		return InstrumentType.Drums;
	}

	void Update()
	{
	}

	void Draw(ref MFRect vp, long offset, Performer performer)
	{
		float time = offset * (1.0f/1_000_000.0f);

		Song song = performer.performance.song;

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
		MFStateBlock* pViewState = MFStateBlock_Clone(MFView_GetViewState());
		MFStateBlock_SetViewport(pViewState, vp);


		// HACK: horrible way to render!
		// stolen from the old C++ feedback, but it'll do for now...
		MFMaterial_SetMaterial(fretboard);
		MFPrimitive(PrimType.TriStrip, 0);

		int start = -4;
		int end = 60;
		int fadeStart = end - 10;

		float fretboardRepeat = 15.0f;
		float fretboardWidth = 7.0f;

		float columnWidth = fretboardWidth / 5.0f;
		float ringBorder = 0.1f;

		// draw the fretboard...
		MFBegin(((end-start) / 4) * 2 + 2);
		MFSetColourV(MFVector.white);

		float halfFB = fretboardWidth*0.5f;

		enum float scrollSpeed = 12;

		float scrollOffset = time*scrollSpeed;
		float topTime = time + end/scrollSpeed;
		float bottomTime = time + start/scrollSpeed;

		int a;
		float textureOffset = fmodf(scrollOffset, fretboardRepeat);
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
		MFBegin(34);

		MFSetColour(0.0f, 0.0f, 0.0f, 0.3f);
		for(int col=1; col<5; col++)
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

		int bottomTick = song.CalculateTickAtTime(cast(long)(bottomTime*1_000_000.0f));
		int res = song.resolution;
		int ticks = bHalfFrets ? res/2 : res;
		int fretBeat = bottomTick + ticks - 1;
		fretBeat -= fretBeat % ticks;
		float fretTime = song.CalculateTimeOfTick(fretBeat) * (1.0f/1_000_000.0f);

		while(fretTime < topTime)
		{
			bool halfBeat = (fretBeat % res) != 0;
			bool bar = false;

			if(!halfBeat)
			{
				ptrdiff_t lastTS = song.sync.GetMostRecentEvent(fretBeat, SyncEventType.TimeSignature);

				if(lastTS != -1)
					bar = ((fretBeat - song.sync[lastTS].tick) % (song.sync[lastTS].timeSignature*res)) == 0;
				else if(fretBeat == 0)
					bar = true;
			}

			float bw = bar ? barWidth : barWidth*0.5f;
			MFBegin(4);

			float position = (fretTime - time) * scrollSpeed;

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
			fretTime = song.CalculateTimeOfTick(fretBeat) * (1.0f/1_000_000.0f);
		}

		MFView_Pop();


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
	}

	Material fretboard;
	Material bar;
	Material edge;
}
