module db.formats.ksf;

import fuji.filesystem;
import fuji.heap;
import fuji.dbg;

import db.chart;
import db.instrument;
import db.instrument.dance : DanceNotes;
import db.tools.filetypes;
import db.library;

import std.algorithm;
import std.string;
import std.path;
import std.exception;
import std.array;
import std.conv : to;

bool LoadKSF(Song* song, DirEntry file, SongLibrary library)
{
	string steps = enforce(MFFileSystem_LoadText(file.filepath).assumeUnique, "");

	string path = file.directory ~ "/";

	MFDebug_Log(2, "Loading song: '" ~ file.filepath ~ "'");

	size_t sep = file.directory.lastIndexOf("/");
	if (sep == -1)
		return false;
	string name = file.directory[sep+1..$];

	string[] n = splitter(name, '-').array;
	assert(n.length == 2, "Song folder should be in 'Artist - Song' format");
	string artist = n[0].strip;
	string songName = n[1].strip;

	string id = archiveName(artist, songName);

	Song* find = library.find(id);
	if (!find)
	{
		song._chart = new Chart;
		song._chart.params["source_format"] = ".ksf";

		song._chart.id = id;
		song._chart.name = songName;
		song._chart.artist = artist;

		// search for the music and other stuff...
		foreach (f; dirEntries(path ~ "*", SpanMode.shallow))
		{
			string filename = f.filename.toLower;
			string fn = filename.stripExtension;
			if (isImageFile(filename))
			{
				if (fn[] == "disc")
					song.coverImage = f.filepath;
				else if (fn[] == "back" || fn[] == "title" || fn[] == "title-bg")
					song.background = f.filepath;
			}
			else if (isAudioFile(filename))
			{
				if (fn[] == "song")
					song.addSource().addStream(f.filepath);
				if (fn[] == "intro")
					song._preview = f.filepath;
			}
			else if (isVideoFile(filename))
			{
				if (fn[] == "song")
					song.video = f.filepath;
			}
		}

		song._chart.LoadKSF(steps, file.filename);
		return true;
	}
	else
	{
		find._chart.LoadKSF(steps, file.filename);
		find._chart.saveChart(path);
		return false;
	}
}

bool LoadKSF(Chart chart, const(char)[] ksf, const(char)[] filename)
{
	with(chart)
	{
		// Format description:
		// https://code.google.com/p/sm-ssc/source/browse/Docs/SimfileFormats/KSF/ksf-format.txt?name=stepsWithScore

		const(int)[] panels;

		enum KsfResolution = 48;
		resolution = KsfResolution;

		string type, difficulty;
		bool bParseMetadata;

		with(DanceNotes)
		{
			__gshared immutable int[10] mapPump = [ DownLeft,UpLeft,Center,UpRight,DownRight,DownLeft2,UpLeft2,Center2,UpRight2,DownRight2 ];

			switch (filename)
			{
				case "Easy_1.ksf":
					type = "pump-single";
					difficulty = "Easy";
					panels = mapPump[0..5];
					bParseMetadata = true;
					break;
				case "Hard_1.ksf":
					type = "pump-single";
					difficulty = "Medium";
					panels = mapPump[0..5];
					bParseMetadata = true;
					break;
				case "Crazy_1.ksf":
					type = "pump-single";
					difficulty = "Hard";
					panels = mapPump[0..5];
					bParseMetadata = true;
					break;
				case "Easy_2.ksf":
					type = "pump-couple";
					panels = mapPump;
					difficulty = "Easy";
					break;
				case "Hard_2.ksf":
					type = "pump-couple";
					panels = mapPump;
					difficulty = "Medium";
					break;
				case "Crazy_2.ksf":
					type = "pump-couple";
					panels = mapPump;
					difficulty = "Hard";
					break;
				case "Double.ksf":
					type = "pump-double";
					panels = mapPump;
					difficulty = "Medium";
					break;
				case "CrazyDouble.ksf":
					type = "pump-double";
					panels = mapPump;
					difficulty = "Hard";
					break;
				case "HalfDouble.ksf":
					type = "pump-double";
					panels = mapPump;
					difficulty = "Easy";	// NOTE: Should this be 'Easy', or 'Half'? Is the reduction to make it easier?
					break;
				default:
					MFDebug_Warn(2, "Unknown .ksf file difficulty: " ~ filename);
					return true;
			}
		}

		Track trk = new Track;
		trk.part = "dance";
		trk.variation = type;
		trk.difficulty = difficulty;

		bool bParseSync = sync.length == 0;
		int step;

		while (1)
		{
			auto start = ksf.find('#');
			if (!start)
				break;
			size_t split = start.countUntil(':');
			if (split == -1)
				break;

			// get the tag
			auto tag = start[1..split];
			auto end = countUntil(start[split..$], ";");

			// get the content
			const(char)[] content;
			if (end != -1)
			{
				content = start[split+1 .. split+end];
				ksf = start[split+end+1..$];
			}
			else
			{
				content = start[split+1 .. $];
				ksf = null;
			}

			switch (tag)
			{
				case "TITLE":
					// We take it from the folder name; some difficulties of some songs seem to keep junk in #TITLE
					if (bParseMetadata)
					{
						// "Artist - Title"
						//						name = content.idup;
					}
					break;
				case "STARTTIME":
					// this may be different for each chart... which means each chart sync's differently.
					// TODO: we need to convert differing offsets into extra measures with no steps.
					long offset = cast(long)(to!double(content)*10_000.0);
					if (startOffset != 0 && startOffset != offset)
					{
						MFDebug_Warn(2, "#STARTTIME doesn't match other .ksf files in: " ~ filename);

						if (offset < startOffset)
						{
							// TODO: add extra measures, push existing notes forward
						}
						else if (offset > startOffset)
						{
							// TODO: calculate an offset to add to all notes that we parse on this chart
							// ie, find the tick represented by this offset - startOffset.
						}
					}
					startOffset = offset;
					break;
				case "TICKCOUNT":
					step = resolution / to!int(content);
					break;
				case "DIFFICULTY":
					trk.difficultyMeter = to!int(content);
					break;
				default:
					// BPM/BUNKI
					if (tag == "BPM")
					{
						if (bParseSync)
						{
							Event ev;
							ev.tick = 0;

							// we need to write a time signature first...
							ev.event = EventType.TimeSignature;
							ev.ts.numerator = 4;
							ev.ts.denominator = 4;
							sync ~= ev;

							// set the starting BPM
							ev.event = EventType.BPM;
							ev.bpm.usPerBeat = cast(int)(60_000_000.0 / to!double(content) + 0.5);
							sync ~= ev;
						}
						else
						{
							// TODO: validate that it matches the previously parsed data?
							if (sync[1].bpm.usPerBeat != cast(int)(60_000_000.0 / to!double(content) + 0.5))
								MFDebug_Warn(2, "#BPM doesn't match other .ksf files in: " ~ filename);
						}
					}
					else if (tag.length > 3 && tag[0..3] == "BPM")
					{
						if (bParseSync)
						{
							int index = tag[3] - '0';

							while (sync.length <= index)
							{
								Event ev;
								ev.event = EventType.BPM;
								sync ~= ev;
							}

							sync[index].bpm.usPerBeat = cast(int)(60_000_000.0 / to!double(content) + 0.5);
						}
						else
						{
							// TODO: validate that it matches the previously parsed data?
						}
					}
					else if (tag.length >= 5 && tag[0..5] == "BUNKI")
					{
						if (bParseSync)
						{
							int index = tag.length > 5 ? tag[5] - '0' + 1 : 2;

							while (sync.length <= index)
							{
								Event ev;
								ev.event = EventType.BPM;
								sync ~= ev;
							}

							long time = cast(long)(to!double(content) * 10_000.0);
							sync[index].tick = calculateTickAtTime(time);
						}
						else
						{
							// TODO: validate that it matches the previously parsed data?
						}
					}
					else
					{
						MFDebug_Warn(2, "Unknown tag: " ~ tag);
					}
					break;

				case "STEP":
					content = content.strip;

					ptrdiff_t[10] holds = -1;

					auto lines = content.splitLines;
					foreach (int i, l; lines)
					{
						if (l[0] == '2')
							break;

						int offset = i*step;
						for (int j=0; j<panels.length; ++j)
						{
							if (l[j] == '0')
							{
								holds[j] = -1;
							}
							else
							{
								if (l[j] == '1' || l[j] == '4' && holds[j] == -1)
								{
									// place note
									Event ev;
									ev.tick = offset;
									ev.event = EventType.Note;
									ev.note.key = panels[j];
									trk.notes ~= ev;
								}
								if (l[j] == '4')
								{
									if (holds[j] == -1)
										holds[j] = trk.notes.length-1;
									else
										trk.notes[holds[j]].duration = offset - trk.notes[holds[j]].tick;
								}
							}
						}
					}
					break;
			}
		}

		// find variation, if there isn't one, create it.
		Variation* pVariation = getVariation(chart.getPart("dance"), trk.variation, true);

		// create difficulty, set difficulty to feet rating
		assert(!getDifficulty(*pVariation, trk.difficulty), "Difficulty already exists!");
		pVariation.difficulties ~= trk;

		return false;
	}
}
