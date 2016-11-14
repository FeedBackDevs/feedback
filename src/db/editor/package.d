module db.editor;

import db.chart;
import db.game : Game;
import db.game.performance;
import db.game.player;
import db.library;
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
import std.range : array;
import std.conv : to;

class Editor
{
	this()
	{
		LayoutDescriptor desc = new LayoutDescriptor("editor.xml");
		if (!desc)
		{
			logWarning(2, "Couldn't load editor.xml");
			return;
		}

		ui = cast(Frame)desc.spawn();
		if (!ui)
		{
			logWarning(2, "Couldn't spawn editor UI!");
			return;
		}

		// make local UI
		menu = new Listbox();
		menu.bgColour = MFVector.black;
		menu.layoutJustification = Justification.Center;
		menu.visibility = Visibility.Gone;
		ui.addChild(menu);

		fileSelector = new FileSelector;
		fileSelector.title = "Select Chart";
		fileSelector.filter = "*.chart";
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

		// show the editor ui
		game.ui.addTopLevelWidget(ui);

		// hide the theme ui
		game.theme.ui.visibility = Visibility.Gone;

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
		syncTtrack = null;
		globalEvents = null;
		partEvents = null;
		track = null;

		editorPlayer = null;

		game.performance = null;

		// hide editor ui
		game.ui.removeTopLevelWidget(ui);

		// return to the theme
		game.theme.ui.visibility = Visibility.Visible;
		game.ui.registerUnhandledInputHandler(oldInputHandler);
		oldInputHandler = null;

		game = null;

		bInEditor = false;
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

	int offset;
	long time;
	int step = 4;

	Player editorPlayer;

	Song* pSong;
	Chart chart;
	Track syncTtrack;
	Track globalEvents;
	Track partEvents;
	Track track;

	SystemTimer sync;

	Frame ui;
	Listbox menu;
	FileSelector fileSelector;

	__gshared string[] allParts = [
		"leadguitar", "rhythmguitar", "bass",
		"realleadguitar", "realrhythmguitar", "realbass",
		"keyboard", "realkeyboard",
		"drums",
		"vocals",
		"dance"
	];
	__gshared string[] drumTypes = [
		"4-drums", "5-drums", "6-drums", "7-drums", "8-drums",
	];
	__gshared string[] danceTypes = [
		"dance-single", "dance-double", "dance-couple", "dance-solo",
		"pump-single", "pump-double", "pump-couple",
		"dance-8pad-single", "dance-8pad-double",
		"dance-9pad-single", "dance-9pad-double",
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

	void showMenu(string[] list, void delegate(Widget, int) select, MFVector size = MFVector(400, 300))
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

	void changeTrack(string part, string track, string variation, Difficulty difficulty)
	{
		editorPlayer.input.part = part;
		editorPlayer.input.type = track;
		editorPlayer.variation = variation;
		editorPlayer.difficulty = difficulty;

		game.performance.setPlayers((&editorPlayer)[0..1]);
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
						case MenuState.ChooseTrack:
						case MenuState.NewTrack:
							showMainMenu();
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
					if (ev.button.shift)
					{
						time = 0; // shift-space restarts from start
						sync.reset(time);
					}
					play(!bPlaying);
					return true;
				}
				case MFKey.Up:
				case MFKey.Down:
				{
					if (menuState != MenuState.Closed || bPlaying)
						return true;
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

					menuItems = chart.parts.keys;
					menuItems ~= "[New Part]";

					showMenu(menuItems, &selectPart, MFVector(200, 200));
					menuState = MenuState.ChooseTrack;
					return true;
				}
				default:
					break;
			}
		}
		return false;
	}

	void menuSelect(Widget w, int i)
	{
		switch (i)
		{
			case 1:
				hideMenu();
				fileSelector.root = "songs:";
				fileSelector.visibility = Visibility.Visible;
				menuState = MenuState.NewFile;
				break;
			case 2:
				menuItems = game.songLibrary.songs;
				showMenu(menuItems, &songSelect);
				menuState = MenuState.OpenFile;
				break;
			case 3:
				break;
			case 4:
				break;
			case 5:
				// TODO: want to save?!
				exit();
				break;
			default:
				break;
		}
	}

	void selectPart(Widget w, int i)
	{
		--i; // i is always out by one

		hideMenu();

		selectedPart = null;
		selectedType = null;
		selectedVariation = null;

		if (i == menuItems.length - 1)
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
			return;
		}
		if (i >= 0 && i < menuItems.length)
		{
			selectedPart = menuItems[i];

			Part* pPart = &chart.parts[selectedPart];
			string[] types = pPart.types;
			assert(types.length > 0);
			if (types.length > 1 || selectedPart == "drums" || selectedPart[] == "dance")
			{
				menuItems = types;
				menuItems ~= "[New Type]";
				showMenu(menuItems, &selectType, MFVector(200, 200));
				menuState = MenuState.ChooseTrack;
				return;
			}
			selectedType = types[0];

			string[] variations = pPart.variationsForType(selectedType);
			assert(variations.length > 0);
			if (variations.length > 1)
			{
				menuItems = variations;
				showMenu(menuItems, &selectVariation, MFVector(200, 200));
				menuState = MenuState.ChooseTrack;
				return;
			}

			// select nearest difficulty
			editorPlayer.difficulty = chart.getVariation(selectedPart, selectedType, variations[0]).nearestDifficulty(editorPlayer.difficulty);

			// change the track
			changeTrack(selectedPart, selectedType, variations[0], editorPlayer.difficulty);
		}
	}

	void selectType(Widget w, int i)
	{
		--i; // i is always out by one

		hideMenu();

		Part* pPart = &chart.parts[selectedPart];

		if (i == menuItems.length - 1)
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
			return;
		}
		if (i >= 0 && i < menuItems.length)
		{
			selectedType = menuItems[i];

			string[] variations = pPart.variationsForType(selectedType);
			assert(variations.length > 0);
			if (variations.length > 1)
			{
				menuItems = variations;
				showMenu(menuItems, &selectVariation, MFVector(200, 200));
				menuState = MenuState.ChooseTrack;
				return;
			}

			// select nearest difficulty
			editorPlayer.difficulty = chart.getVariation(selectedPart, selectedType, variations[0]).nearestDifficulty(editorPlayer.difficulty);

			// change the track
			changeTrack(selectedPart, selectedType, variations[0], editorPlayer.difficulty);
		}
	}

	void selectVariation(Widget w, int i)
	{
		--i; // i is always out by one

		hideMenu();

		if (i >= 0 && i < menuItems.length)
		{
			selectedVariation = menuItems[i];

			// select nearest difficulty
			editorPlayer.difficulty = chart.getVariation(selectedPart, selectedType, selectedVariation).nearestDifficulty(editorPlayer.difficulty);

			// change the track
			changeTrack(selectedPart, selectedType, selectedVariation, editorPlayer.difficulty);
		}
	}

	void newTrack(Widget w, int i)
	{
		--i; // i is always out by one

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
			chart.createTrack(selectedPart, selectedType, selectedVariation, diff);
			changeTrack(selectedPart, selectedType, selectedVariation, diff);
		}
	}

	void newChart(Widget w, DirEntry e)
	{
//		Game.perfo
	}

	void songSelect(Widget w, int i)
	{
		hideMenu();

		if (bPlaying)
			play(false);

		pSong = game.songLibrary.find(menuItems[i-1]);
		if (!pSong)
		{
			game.performance = null;
			return;
		}

		// reset the clock
		sync.pause(true);
		sync.reset();

		game.performance = new Performance(pSong, (&editorPlayer)[0..1], sync);
		chart = pSong.chart;

		gotoTick(0);
		step = 4;

		done: foreach (ref p; chart.parts)
		{
			foreach (ref v; p.variations)
			{
				foreach (ref trk; v.difficulties)
				{
					changeTrack(trk.part, trk.variationType, trk.variationName, trk.difficulty);
					break done;
				}
			}
		}
	}
}
