module db.tracks.helpers;

import db.chart;
import db.game;
import db.i.notetrack;
import fuji.font;
import fuji.string;
import fuji.types;
import fuji.vector;
import fuji.view;
import std.algorithm : sort, filter;
import std.range : chain, array;

immutable MFVector[] eventColours = [
	MFVector.black, // Unknown
	MFVector.green, // BPM
	MFVector.yellow, // Anchor
	MFVector.yellow, // Freeze
	MFVector.yellow, // TimeSignature
	MFVector.white, // Note
	MFVector.white, // GuitarNote
	MFVector.cyan, // Lyric
	MFVector.white, // Special
	MFVector.white, // Event
	MFVector.blue, // Section
	MFVector.magenta, // DrumAnimation
	MFVector.magenta, // Chord
	MFVector.magenta, // NeckPosition
	MFVector.magenta, // KeyboardPosition
	MFVector.cyan, // Lighting
	MFVector.orange, // DirectedCut
	MFVector.white // MIDI
];

void renderEditorText(Chart chart, Track trk, NoteTrack track, long time)
{
	if (!Game.instance.inEditor)
		return;

	long bottomTime, topTime;
	track.GetVisibleRange(time, null, null, &bottomTime, &topTime);

	MFView_Push();

	MFRect rect = MFRect(0, 0, 1920, 1080);
	MFView_SetOrtho(&rect);

	auto syncEvents = chart.sync.BetweenTimes(bottomTime, topTime);
	auto songEvents = chart.events.BetweenTimes(bottomTime, topTime);
	auto partEvents = chart.parts[trk.part].events.BetweenTimes(bottomTime, topTime);
	auto trackEvents = trk.notes.BetweenTimes(bottomTime, topTime);
	auto events = chain(syncEvents,
						partEvents.filter!((ref e) => e.event != EventType.MIDI),
						trackEvents.filter!((ref e) => e.event != EventType.Note && e.event != EventType.Special && e.event != EventType.GuitarNote && e.event != EventType.MIDI)
						).array.sort();

	Font font = Font.debugFont;
	enum textHeight = 35.0;

	size_t first = 0;
	for (size_t i = 1; i <= events.length; ++i)
	{
		if (i == events.length || events[i].tick > events[i-1].tick)
		{
			size_t num = i - first;

			MFVector pos = track.GetPosForTime(time, events[first].time, RelativePosition.Right);
			MFVector r;
			MFView_TransformPoint3DTo2D(pos, &r);
			r.x += 40.0;
			r.y -= (num - 1)*textHeight;

			foreach (j; 0 .. num)
			{
				Event* e = &events[first + j];
				font.drawAnchored(e.toDisplayString!false(), r, MFFontJustify.Center_Left, 1920.0f, 30.0f, eventColours[e.event]);
				r.y += textHeight;
			}

			first = i;
		}
	}

	first = 0;
	for (size_t i = 1; i <= songEvents.length; ++i)
	{
		if (i == songEvents.length || songEvents[i].tick > songEvents[i-1].tick)
		{
			size_t num = i - first;

			MFVector pos = track.GetPosForTime(time, songEvents[first].time, RelativePosition.Left);
			MFVector r;
			MFView_TransformPoint3DTo2D(pos, &r);
			r.x -= 40.0;
			r.y -= (num - 1)*textHeight;

			foreach (j; 0 .. num)
			{
				Event* e = &songEvents[first + j];
				font.drawAnchored(e.toDisplayString!false(), r, MFFontJustify.Center_Right, 1920.0f, 30.0f, eventColours[e.event]);
				r.y += textHeight;
			}

			first = i;
		}
	}

//	int tick = chart.calculateTickAtTime(offset);
//	MFFont_DrawText2(null, 1920 - 200, 10, 20, MFVector.yellow, ("Time: " ~ to!string(offset/1_000_000.0)).toStringz);
//	MFFont_DrawText2(null, 1920 - 200, 30, 20, MFVector.orange, ("Offset: " ~ to!string(tick/cast(double)chart.resolution)).toStringz);

	MFView_Pop();
}
