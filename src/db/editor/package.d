module db.editor;

import db.chart;
import db.game : Game;
import db.game.performance;
import db.game.player;
import db.instrument.dance : DanceNotes;
import db.instrument.drums : DrumNotes;
import db.instrument.guitarcontroller : GuitarNotes;
import db.instrument.keyboard: KeyboardNotes;
import db.library;
import db.lua : lua, LuaFunction, LuaObject;
import db.sync.systime;
import db.theme;
import db.ui.inputmanager : InputSource;
import db.ui.layoutdescriptor;
import db.ui.listadapter;
import db.ui.ui : InputManager, InputEventDelegate;
import db.ui.widget;
import db.ui.widgets.fileselector;
import db.ui.widgets.frame;
import db.ui.widgets.label;
import db.ui.widgets.listbox;
import fuji.dbg;
import fuji.filesystem : DirEntry;
import fuji.font;
import fuji.input;
import fuji.vector;
import std.algorithm : max, clamp, canFind, filter;
import std.range : array, retro;
import std.conv : to;

class Editor
{
	this()
	{
		ui = cast(Frame)lua.get!Widget("theme", "editor", "ui");

		// make local UI
		menu = new Listbox();
		menu.bgColour = MFVector.black;
		menu.layoutJustification = Justification.Center;
		menu.visibility = Visibility.Gone;
		ui.addChild(menu);

		fileSelector = new FileSelector;
		fileSelector.title = "Select Main Audio Track";
		fileSelector.filter = "*.mp3;*.ogg;*.wav";
		fileSelector.root = "songs:";
		fileSelector.layoutJustification = Justification.Center;
		fileSelector.visibility = Visibility.Gone;
		fileSelector.OnSelectFile ~= &newChart;
		ui.addChild(fileSelector);

		sync = new SystemTimer;
	}

	void enter()
	{
		game = Game.instance;

		// set input hook
		oldInputHandler = game.ui.registerUnhandledInputHandler(&inputEvent);

		// setup editor player
		InputSource* pKeyboard = Game.instance.ui.findInputSource(MFInputDevice.Keyboard, 0);
		editorPlayer = new Player(pKeyboard, null);
		editorPlayer.input.part = "leadguitar";
		editorPlayer.variation = null;
		editorPlayer.difficulty = Difficulty.Expert;

		showMainMenu();

		bInEditor = true;
	}

	void exit()
	{
		if (bPlaying)
			play(false);

		// clean up
		pSong = null;
		chart = null;
		track = null;

		editorPlayer = null;

		game.performance = null;

		// return to input handler
		game.ui.registerUnhandledInputHandler(oldInputHandler);
		oldInputHandler = null;

		game = null;

		bInEditor = false;

		lua.get!LuaFunction("theme", "editor", "exit")(lua.get!LuaObject("theme", "editor"));
	}

	void update()
	{
		if (!bInEditor)
			return;

		if (bPlaying)
		{
			time = cast(long)(sync.seconds * 1_000_000);
			offset = max(chart.calculateTickAtTime(time), 0);
		}
	}

	void draw()
	{
		if (!bInEditor)
			return;
	}

	void drawUi()
	{
		import fuji.display : MFDisplay_GetDisplayRect;

		if (!bInEditor)
			return;

		if (chart)
		{
			Font font = Font.debugFont();

			MFFont_DrawText2f(null, 10, 10, 20, MFVector.yellow, "Offset: %g", cast(double)offset / chart.resolution);
			MFFont_DrawText2f(null, 10, 30, 20, MFVector.yellow, "Time: %d:%02d.%03d", time / 60_000_000, time / 1_000_000 % 60, time / 1_000 % 1_000);
			MFFont_DrawText2f(null, 10, 50, 20, MFVector.yellow, "Step: 1/%d", step);

			MFRect rect;
			MFDisplay_GetDisplayRect(&rect);

			MFVector pos = MFVector(rect.width - 10, 10);
			font.drawAnchored(chart.name, pos, MFFontJustify.Top_Right, rect.width, 20, MFVector.white);
			pos.y += 20;
			font.drawAnchored(chart.artist, pos, MFFontJustify.Top_Right, rect.width, 20, MFVector.white);
			pos.y += 30;
			if (editorPlayer.input.type)
				font.drawAnchored(editorPlayer.input.type, pos, MFFontJustify.Top_Right, rect.width, 20, MFVector.white);
			else
				font.drawAnchored(editorPlayer.input.part, pos, MFFontJustify.Top_Right, rect.width, 20, MFVector.white);
			pos.y += 20;
			font.drawAnchored(to!string(editorPlayer.difficulty), pos, MFFontJustify.Top_Right, rect.width, 20, MFVector.white);
			if (editorPlayer.variation)
			{
				pos.y += 20;
				font.drawAnchored(editorPlayer.variation, pos, MFFontJustify.Top_Right, rect.width, 20, MFVector.white);
			}
		}
	}

	Game game;
	InputEventDelegate oldInputHandler;

	bool bInEditor, bPlaying;

	int offset, playOffset;
	long time;
	int step = 4;

	Player editorPlayer;

	Song* pSong;
	Chart chart;
	Track track;

	SystemTimer sync;

	Frame ui;
	Listbox menu;
	FileSelector fileSelector;

	__gshared string[] allParts = [
		"leadguitar", "rhythmguitar", "bass",
		"drums",
		"keyboard", "realkeyboard",
		"realleadguitar", "realrhythmguitar", "realbass",
		"vocals",
		"dance"
	];
	__gshared string[] drumTypes = [
		"real-drums", "pro-drums", "gh-drums", "rb-drums"
	];
	__gshared string[] danceTypes = [
		"dance-single", "dance-double", "dance-couple", "dance-solo",
		"pump-single", "pump-double", "pump-couple",
		"dance-8pad-single", "dance-8pad-double",
		"dance-9pad-single", "dance-9pad-double"
	];

	enum MenuState
	{
		Closed,
		MainMenu,
		NewFile,
		OpenFile,
		ChooseTrack,
		NewTrack,
	}
	MenuState menuState;
	string[] menuItems;

	string selectedPart, selectedType, selectedVariation;
	bool donePart, doneType, doneVariation;

	int[] noteMap;

	void shift(int steps)
	{
		gotoTick(offset + (steps * chart.resolution * 4 / step), false);
	}

	void gotoTick(int offset, bool roundToStep = true)
	{
		this.offset = max(offset, 0);
		if (roundToStep)
			this.offset -= offset % (chart.resolution * 4 / step);
		time = chart.calculateTimeOfTick(this.offset);
		sync.reset(time);
	}

	void gotoTime(long time, bool roundToStep = true)
	{
		offset =  max(chart.calculateTickAtTime(time), 0);
		if (roundToStep)
		{
			offset -= offset % (chart.resolution * 4 / step);
			this.time = chart.calculateTimeOfTick(offset);
		}
		else
			this.time = time;
		sync.reset(this.time);
	}

	void play(bool playing = true)
	{
		if (playing && !bPlaying)
		{
			game.performance.begin(cast(double)time / 1_000_000);

			bPlaying = true;
		}
		else if (!playing && bPlaying)
		{
			game.performance.pause(true);

			gotoTime(sync.now);

			bPlaying = false;
		}
	}

	void showMenu(string[] list, void delegate(int, Widget) select, MFVector size = MFVector(400, 300))
	{
		menu.list = new StringList(list, (Label l) { l.textColour = MFVector.white; });
		menu.size = size;
		menu.selection = 0;
		menu.OnClick.clear();
		menu.OnClick ~= select;
		menu.visibility = Visibility.Visible;
	}
	void hideMenu()
	{
		menu.visibility = Visibility.Gone;
		menuState = MenuState.Closed;
	}
	void showMainMenu()
	{
		showMenu([ "New Chart", "Open Chart", "Save Chart", "Chart Settings", "Exit" ], &menuSelect);
		menuState = MenuState.MainMenu;
	}

	void showSelectTrack()
	{
		menuItems = chart.parts.keys;
		menuItems ~= "[New Part]"; // TODO: don't display if all parts are present...

		showMenu(menuItems, &selectTrack, MFVector(200, 200));
		menuState = MenuState.ChooseTrack;

		selectedPart = null;
		selectedType = null;
		selectedVariation = null;
		donePart = false;
		doneType = false;
		doneVariation = false;
	}

	void changeTrack(string part, string track, string variation, Difficulty difficulty)
	{
		Track trk = chart.getVariation(part, track, variation).difficulty(difficulty);
		changeTrack(trk);
	}

	void changeTrack(Track trk)
	{
		track = trk;

		editorPlayer.input.part = trk.part;
		editorPlayer.input.type = trk.variationType;
		editorPlayer.variation = trk.variationName;
		editorPlayer.difficulty = trk.difficulty;

		game.performance.setPlayers((&editorPlayer)[0..1]);

		noteMap = getNoteMap(trk.part, trk.variationType);
	}

	int[] getNoteMap(string part, string type)
	{
		switch (part)
		{
			case "leadguitar":
			case "rhythmguitar":
			case "bass":
				return [ GuitarNotes.Open, GuitarNotes.Green, GuitarNotes.Red, GuitarNotes.Yellow, GuitarNotes.Blue, GuitarNotes.Orange, GuitarNotes.Open, -1, -1, -1 ];
			case "keyboard":
				return [ -1, KeyboardNotes.Green, KeyboardNotes.Red, KeyboardNotes.Yellow, KeyboardNotes.Blue, KeyboardNotes.Orange, -1, -1, -1, -1 ];
			case "drums":
				switch (type)
				{
					case "rb-drums":
						return [ DrumNotes.Kick, DrumNotes.Snare, DrumNotes.Tom1, DrumNotes.Tom2, DrumNotes.Tom3, DrumNotes.Kick, -1, -1, -1, -1 ];
					case "gh-drums":
						return [ DrumNotes.Kick, DrumNotes.Snare, DrumNotes.Crash, DrumNotes.Tom2, DrumNotes.Ride, DrumNotes.Tom3, DrumNotes.Kick, -1, -1, -1 ];
					case "pro-drums":
						return [ DrumNotes.Kick, DrumNotes.Snare, DrumNotes.Tom1, DrumNotes.Tom2, DrumNotes.Tom3, DrumNotes.Hat, DrumNotes.Ride, DrumNotes.Crash, DrumNotes.Kick, -1 ];
					case "real-drums-2c":
						return [ DrumNotes.Kick, DrumNotes.Hat, DrumNotes.Snare, DrumNotes.Crash, DrumNotes.Tom1, DrumNotes.Tom2, DrumNotes.Ride, DrumNotes.Tom3, DrumNotes.Kick, -1 ];
					case "real-drums":
						return [ DrumNotes.Kick, DrumNotes.Hat, DrumNotes.Snare, DrumNotes.Crash, DrumNotes.Tom1, DrumNotes.Splash, DrumNotes.Tom2, DrumNotes.Ride, DrumNotes.Tom3, DrumNotes.Kick ];
					default:
						break;
				}
				goto default;
			case "dance":
				switch (type)
				{
					case "dance-single":
						return [ cast(DanceNotes)-1, DanceNotes.Left, DanceNotes.Down, DanceNotes.Up, DanceNotes.Right, cast(DanceNotes)-1, cast(DanceNotes)-1, cast(DanceNotes)-1, cast(DanceNotes)-1, cast(DanceNotes)-1 ];
					case "dance-double":
					case "dance-couple":
						return [ cast(DanceNotes)-1, DanceNotes.Left, DanceNotes.Down, DanceNotes.Up, DanceNotes.Right, DanceNotes.Left2, DanceNotes.Down2, DanceNotes.Up2, DanceNotes.Right2, cast(DanceNotes)-1 ];
					case "dance-solo":
						return [ cast(DanceNotes)-1, DanceNotes.Left, DanceNotes.UpLeft, DanceNotes.Down, DanceNotes.Up, DanceNotes.UpRight, DanceNotes.Right, cast(DanceNotes)-1, cast(DanceNotes)-1, cast(DanceNotes)-1 ];
					case "pump-single":
						return [ cast(DanceNotes)-1, DanceNotes.DownLeft, DanceNotes.UpLeft, DanceNotes.Center, DanceNotes.UpRight, DanceNotes.DownRight, cast(DanceNotes)-1, cast(DanceNotes)-1, cast(DanceNotes)-1, cast(DanceNotes)-1 ];
					case "pump-double":
					case "pump-couple":
						return [ DanceNotes.DownRight2, DanceNotes.DownLeft, DanceNotes.UpLeft, DanceNotes.Center, DanceNotes.UpRight, DanceNotes.DownRight, DanceNotes.DownLeft2, DanceNotes.UpLeft2, DanceNotes.Center2, DanceNotes.UpRight2 ];
					case "dance-8pad-single":
						return [ cast(DanceNotes)-1, DanceNotes.DownLeft, DanceNotes.Left, DanceNotes.UpLeft, DanceNotes.Down, DanceNotes.Up, DanceNotes.UpRight, DanceNotes.Right, DanceNotes.DownRight, cast(DanceNotes)-1 ];
					case "dance-9pad-single":
						return [ cast(DanceNotes)-1, DanceNotes.DownLeft, DanceNotes.Left, DanceNotes.UpLeft, DanceNotes.Down, DanceNotes.Center, DanceNotes.Up, DanceNotes.UpRight, DanceNotes.Right, DanceNotes.DownRight ];
					default:
						break;
				}
				goto default;
			default:
				return [ -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ];
		}
	}

	//
	// MENU LOGIC
	//

	bool inputEvent(InputManager inputManager, const(InputManager.EventInfo)* ev)
	{
		if (ev.device == MFInputDevice.Keyboard && ev.ev == InputManager.EventType.ButtonDown)
		{
			switch (ev.buttonID)
			{
				case MFKey.Escape:
				{
					switch (menuState)
					{
						case MenuState.NewFile:
							fileSelector.visibility = Visibility.Gone;
							goto case MenuState.Closed;
						case MenuState.Closed:
						case MenuState.OpenFile:
							showMainMenu();
							break;
						case MenuState.ChooseTrack:
						case MenuState.NewTrack:
							hideMenu();
							break;
						case MenuState.MainMenu:
							hideMenu();
							break;
						default:
							break;
					}
					return true;
				}
				case MFKey.Space:
				case MFKey.PlayPause:
				{
					if (menuState != MenuState.Closed)
						return true;
					if (!bPlaying)
					{
						// shift-space plays from start
						if (ev.button.shift)
						{
							offset = 0;
							time = 0;
							sync.reset(time);
						}
						playOffset = offset;

						play(true);
					}
					else
					{
						play(false);

						// shift-space returns to position where play started
						if (ev.button.shift)
							gotoTick(playOffset);
					}
					return true;
				}
				case MFKey.Up:
				case MFKey.Down:
				{
					if (menuState != MenuState.Closed || bPlaying)
						return true;
					if (ev.button.alt)
					{
						// prev/next section
						// TODO ...
					}
					else
						shift(ev.buttonID == MFKey.Up ? 1 : -1);
					return true;
				}
				case MFKey.Left:
				case MFKey.Right:
				{
					if (menuState != MenuState.Closed || bPlaying)
						return true;
					__gshared immutable int[] steps = [ 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64];
					int i = 0;
					while (step > steps[i])
						++i;
					step = steps[clamp(ev.buttonID == MFKey.Left ? i - 1 : i + 1, 0, steps.length-1)];
					gotoTick(offset);
					return true;
				}
				case MFKey.PageUp:
				case MFKey.PageDown:
					{
					if (menuState != MenuState.Closed || bPlaying)
						return true;
					// how many beats in a measure?
					shift(ev.buttonID == MFKey.PageUp ? 4 : -4);
					return true;
				}
				case MFKey.Home:
				{
					if (menuState != MenuState.Closed || bPlaying)
						return true;
					gotoTick(chart.getLastNoteTick());
					return true;
				}
				case MFKey.End:
				{
					if (menuState != MenuState.Closed || bPlaying)
						return true;
					gotoTick(0);
					return true;
				}
				case MFKey.F1:
				{
					// help??
					return true;
				}
				case MFKey.F2:
				{
					if (menuState != MenuState.Closed)
						return true;
					showSelectTrack();
					return true;
				}
				case MFKey.F5:
				case MFKey.F6:
				case MFKey.F7:
				case MFKey.F8:
				case MFKey.F9:
				{
					if (editorPlayer.input.part[] == "vocals")
						return true;

					// select difficulty
					Difficulty diff = cast(Difficulty)(Difficulty.Beginner + (ev.buttonID - MFKey.F5));
					Track trk = chart.getVariation(editorPlayer.input.part, editorPlayer.input.type, editorPlayer.variation).difficulty(diff);
					if (!trk)
					{
						// if the difficulty doesn't exist, create an empty track...
						trk = chart.createTrack(editorPlayer.input.part, editorPlayer.input.type, editorPlayer.variation, diff);
					}

					// change the track
					changeTrack(trk);
					return true;
				}
				case MFKey._0:
				..
				case MFKey._9:
				{
					if (menuState != MenuState.Closed || bPlaying)
						return true;

					int note = noteMap[ev.buttonID - MFKey._0];
					if (note == -1)
						return true;

					// TODO: if we interrupt a sustain, remove the sustained note!
					auto i = track.notes.FindEvent(EventType.Note, offset, note);
					if (i != -1)
					{
						// remove existing note!
						chart.removeEvent(track, &track.notes[i]);
						return true;
					}

					if (track.variationType[] == "pro-drums")
					{
						// enforce RB 'pro-drums' rules, cymbals and toms can't coexist...
						foreach (j, n; [ DrumNotes.Tom1, DrumNotes.Tom2, DrumNotes.Tom3, DrumNotes.Hat, DrumNotes.Ride, DrumNotes.Crash ])
						{
							if (note != n)
								continue;

							i = track.notes.FindEvent(EventType.Note, offset, [ DrumNotes.Hat, DrumNotes.Ride, DrumNotes.Crash, DrumNotes.Tom1, DrumNotes.Tom2, DrumNotes.Tom3 ][j]);
							if (i != -1)
								chart.removeEvent(track, &track.notes[i]);
							break;
						}
					}

					// insert note event at tick
					Event e;
					e.tick = offset;
					e.event = EventType.Note;
					e.note.key = note;
					chart.insertTrackEvent(track, e);
					return true;
				}

				default:
					break;
			}
		}
		return false;
	}

	void menuSelect(int i, Widget w)
	{
		hideMenu();

		switch (i)
		{
			case 0:
				fileSelector.root = "songs:";
				fileSelector.visibility = Visibility.Visible;
				menuState = MenuState.NewFile;
				break;
			case 1:
				menuItems = game.songLibrary.songs;
				showMenu(menuItems, &songSelect);
				menuState = MenuState.OpenFile;
				break;
			case 2:
				chart.saveChart(chart.songPath);
				// TODO: note that it was saved!!
				break;
			case 3:
				break;
			case 4:
				// TODO: want to save?!
				exit();
				break;
			default:
				break;
		}
	}

	void selectTrack(int i, Widget w)
	{
		hideMenu();

		Part *pPart;
		if (donePart)
			pPart = &chart.parts[selectedPart];

		// if we selected 'add new' (TODO: check if menu has add new)
		if (i == menuItems.length - 1)
		{
			if (!donePart)
			{
				string[] parts = chart.parts.keys;
				menuItems = allParts.filter!(e => !parts.canFind(e)).array;
				if (menuItems)
				{
					showMenu(menuItems, &newTrack, MFVector(200, 200));
					menuState = MenuState.NewTrack;
				}
				else
				{
					// TODO: all parts present... make noise?
				}
			}
			else if (!doneType)
			{
				string[] types = pPart.types;
				string[] allTypes;
				if (selectedPart[] == "drums")
					allTypes = drumTypes;
				else if (selectedPart[] == "dance")
					allTypes = danceTypes;
				menuItems = allTypes.filter!(e => !types.canFind(e)).array;
				if (menuItems)
				{
					showMenu(menuItems, &newTrack, MFVector(200, 200));
					menuState = MenuState.NewTrack;
				}
				else
				{
					// TODO: don't know what types to offer?
				}
			}
			return;
		}

		// menu selection
		if (i >= 0 && i < menuItems.length)
		{
			// which selection are we up to?
			if (!donePart)
			{
				selectedPart = menuItems[i];
				donePart = true;

				pPart = &chart.parts[selectedPart];

				string[] types = pPart.types;
				assert(types.length > 0);
				if (types.length > 1 || selectedPart == "drums" || selectedPart[] == "dance")
				{
					menuItems = types;
					menuItems ~= "[New Type]";
					showMenu(menuItems, &selectTrack, MFVector(200, 200));
					menuState = MenuState.ChooseTrack;
					return;
				}

				selectedType = types[0];
				doneType = true;
			}
			else if (!doneType)
			{
				selectedType = menuItems[i];
				doneType = true;
			}
			else if (!doneVariation)
			{
				selectedVariation = menuItems[i];
				doneVariation = true;
			}

			// an earlier step might require selection of a variation
			if (!doneVariation)
			{
				string[] variations = pPart.variationsForType(selectedType);
				assert(variations.length > 0);
				if (variations.length > 1)
				{
					menuItems = variations;
					showMenu(menuItems, &selectTrack, MFVector(200, 200));
					menuState = MenuState.ChooseTrack;
					return;
				}

				selectedVariation = variations[0];
				doneVariation = true;
			}

			// sanity check...
			assert(donePart && doneType && doneVariation);

			// get the variation
			Variation* pVariation = pPart.variation(selectedType, selectedVariation);

			// select nearest difficulty
			Difficulty diff = pVariation.nearestDifficulty(editorPlayer.difficulty);

			// if there are no tracks yet
			if (diff == Difficulty.Unknown)
			{
				// create the expert track by default
				diff = Difficulty.Expert;
				chart.createTrack(selectedPart, selectedType, selectedVariation, diff);
			}

			// change the track
			changeTrack(selectedPart, selectedType, selectedVariation, diff);
		}
	}

	void newTrack(int i, Widget w)
	{
		hideMenu();

		if (i >= 0 && i < menuItems.length)
		{
			if (!selectedPart)
			{
				selectedPart = menuItems[i];

				if (selectedPart[] == "drums")
				{
					menuItems = drumTypes;
					showMenu(menuItems, &newTrack, MFVector(200, 200));
					menuState = MenuState.NewTrack;
					return;
				}
				else if (selectedPart[] == "dance")
				{
					menuItems = danceTypes;
					showMenu(menuItems, &newTrack, MFVector(200, 200));
					menuState = MenuState.NewTrack;
					return;
				}
			}
			else if (!selectedType)
			{
				selectedType = menuItems[i];

				if (chart.hasPart(selectedPart))
				{
					string[] variations = chart.parts[selectedPart].uniqueVariations();
					assert(variations.length > 0);
					if (variations.length > 1)
					{
						menuItems = variations;
						showMenu(menuItems, &newTrack, MFVector(200, 200));
						menuState = MenuState.NewTrack;
						return;
					}
					selectedVariation = variations[0];
				}
			}
			else
				selectedVariation = menuItems[i];

			Difficulty diff = selectedPart[] == "vocals" ? Difficulty.Expert : editorPlayer.difficulty;

			if (selectedPart[] == "drums")
			{
				// TODO: check of other drums parts exist
				//       if so, offer to fabricate from other drums part
			}

			// create the new track
			chart.createTrack(selectedPart, selectedType, selectedVariation, diff);
			changeTrack(selectedPart, selectedType, selectedVariation, diff);
		}
	}

	void newChart(DirEntry e, Widget w)
	{
//		Game.perfo
	}

	void songSelect(int i, Widget w)
	{
		hideMenu();

		if (bPlaying)
			play(false);

		pSong = game.songLibrary.find(menuItems[i]);
		if (!pSong)
		{
			game.performance = null;
			return;
		}

		// reset the clock
		sync.pause(true);
		sync.reset();

		game.performance = new Performance(pSong, null, sync);
		chart = pSong.chart;

		gotoTick(0);
		step = 4;

		done: foreach (p; allParts)
		{
			Part* pPart = p in chart.parts;
			if (!pPart)
				continue;
			foreach (ref v; pPart.variations)
			{
				foreach (ref trk; v.difficulties.retro)
				{
					changeTrack(trk.part, trk.variationType, trk.variationName, trk.difficulty);
					break done;
				}
			}
		}
	}
}
