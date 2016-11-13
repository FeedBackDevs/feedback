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
import std.algorithm : max, clamp;

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
		mainMenu = new Listbox();
		mainMenu.list = new StringList([ "New Chart", "Open Chart", "Save Chart", "Chart Settings", "Exit" ], (Label l) { l.textColour = MFVector.white; });
		mainMenu.size = MFVector(400, 300);
		mainMenu.bgColour = MFVector.black;
		mainMenu.layoutJustification = Justification.Center;
		mainMenu.visibility = Visibility.Visible;
		mainMenu.OnClick ~= &menuSelect;
		ui.addChild(mainMenu);

		selectSong = new Listbox();
		selectSong.size = MFVector(400, 300);
		selectSong.bgColour = MFVector.black;
		selectSong.layoutJustification = Justification.Center;
		selectSong.visibility = Visibility.Gone;
		selectSong.OnClick ~= &songSelect;
		ui.addChild(selectSong);

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

		menuState = MenuState.MainMenu;
		mainMenu.selection = 0;

		bInEditor = true;
	}

	void exit()
	{
		if (bPlaying)
			play(false);

		// clean up
		songs = null;
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
		if (!bInEditor)
			return;

		if (chart)
		{
			MFFont_DrawText2f(null, 10, 10, 20, MFVector.yellow, "Offset: %g", cast(double)offset / chart.resolution);
			MFFont_DrawText2f(null, 10, 30, 20, MFVector.yellow, "Time: %d:%02d.%03d", time / 60_000_000, time / 1_000_000 % 60, time / 1_000 % 1_000);
			MFFont_DrawText2f(null, 10, 50, 20, MFVector.yellow, "Step: 1/%d", step);
		}
	}

	Game game;
	InputEventDelegate oldInputHandler;

	bool bInEditor, bPlaying;

	int offset;
	long time;
	int step = 4;

	Player editorPlayer;

	string[] songs;

	Song* pSong;
	Chart chart;
	Track syncTtrack;
	Track globalEvents;
	Track partEvents;
	Track track;

	SystemTimer sync;

	Frame ui;
	Listbox mainMenu;
	Listbox selectSong;
	FileSelector fileSelector;

	enum MenuState
	{
		Closed,
		MainMenu,
		NewFile,
		OpenFile,
	}
	MenuState menuState;

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
						case MenuState.Closed:
							mainMenu.selection = 0;
							goto showMainMenu;
						case MenuState.MainMenu:
							mainMenu.visibility = Visibility.Gone;
							menuState = MenuState.Closed;
							break;
						case MenuState.NewFile:
							fileSelector.visibility = Visibility.Gone;
							goto showMainMenu;
						case MenuState.OpenFile:
							selectSong.visibility = Visibility.Gone;
							goto showMainMenu;
						showMainMenu:
							mainMenu.visibility = Visibility.Visible;
							menuState = MenuState.MainMenu;
							break;
						default:
							break;
					}
					return true;
				}
				case MFKey.Space:
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
				mainMenu.visibility = Visibility.Gone;
				fileSelector.root = "songs:";
				fileSelector.visibility = Visibility.Visible;
				menuState = MenuState.NewFile;
				break;
			case 2:
				songs = Game.instance.songLibrary.songs;
				selectSong.list = new StringList(songs, (Label l) { l.textColour = MFVector.white; });
				mainMenu.visibility = Visibility.Gone;
				selectSong.selection = 0;
				selectSong.visibility = Visibility.Visible;
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

	void newChart(Widget w, DirEntry e)
	{
//		Game.perfo
	}

	void songSelect(Widget w, int i)
	{
		if (bPlaying)
			play(false);

		selectSong.visibility = Visibility.Gone;
		menuState = MenuState.Closed;

		pSong = game.songLibrary.find(songs[i-1]);
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

		// player should be configured to show the first part -> variation -> difficulty
	}
}
