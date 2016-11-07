module db.game.performance;

import fuji.display;

import db.instrument;
import db.chart : Chart, Track;
import db.library;
import db.game.player;
import db.renderer;

import db.inputs.inputdevice;
import db.i.notetrack;
import db.i.scorekeeper;
import db.i.syncsource;

import db.tracks.guitartrack;
import db.tracks.drumstrack;
import db.tracks.keystrack;
import db.tracks.prokeystrack;
import db.tracks.dancetrack;
import db.scorekeepers.guitar;
import db.scorekeepers.drums;
import db.scorekeepers.keys;
import db.scorekeepers.dance;
import db.sync.systime;

import std.signals;

class Performer
{
	this(Performance performance, Player player, Track sequence)
	{
		this.performance = performance;
		this.player = player;
		this.sequence = sequence;

		// HACK: hardcoded classes for the moment...
		// Note: note track should be chosen accorting to the instrument type, and player preference for theme/style (GH/RB/Bemani?)
		if (player.input.part[] == "leadguitar")
		{
			scoreKeeper = new GuitarScoreKeeper(sequence, player.input.instrument);
			noteTrack = new GHGuitar(this);
		}
		else if (player.input.part[] == "drums")
		{
			scoreKeeper = new DrumsScoreKeeper(sequence, player.input.instrument);
			noteTrack = new GHDrums(this);
		}
		else if (player.input.part[] == "keyboard")
		{
			scoreKeeper = new KeysScoreKeeper(sequence, player.input.instrument);
			noteTrack = new KeysTrack(this);
		}
		else if (player.input.part[] == "realkeyboard")
		{
			scoreKeeper = new KeysScoreKeeper(sequence, player.input.instrument);
			noteTrack = new ProKeysTrack(this);
		}
		else if (player.input.part[] == "dance")
		{
			scoreKeeper = new DanceScoreKeeper(sequence, player.input.instrument);
			noteTrack = new DanceTrack(this);
		}
	}

	void Begin(SyncSource sync)
	{
		scoreKeeper.Begin(player.input.part, sync);
	}

	void End()
	{
	}

	void Update(long now)
	{
		scoreKeeper.Update();
		noteTrack.Update();
	}

	void Draw(long now)
	{
		noteTrack.Draw(screenSpace, now);
	}

	void DrawUI()
	{
		noteTrack.DrawUI(screenSpace);
	}

	MFRect screenSpace;
	Performance performance;
	Player player;
	Track sequence;
	NoteTrack noteTrack;
	ScoreKeeper scoreKeeper;
}

class Performance
{
	this(Song* song, Player[] players)
	{
		this.song = song;
		song.prepare();

		// create and arrange the performers for 'currentSong'
		// Note: Players whose parts are unavailable in the song will not have performers created
		performers = null;
		foreach (p; players)
		{
			Track s = song.chart.GetSequence(p.input.part, p.input.instrument, p.variation, p.difficulty);
			if (s)
				performers ~= new Performer(this, p, s);
			else
			{
				// HACK: find a part the players instrument can play!
				foreach (part; p.input.instrument.desc.parts)
				{
					s = song.chart.GetSequence(part, p.input.instrument, p.variation, p.difficulty);
					if (s)
					{
						p.input.part = part;
						performers ~= new Performer(this, p, s);
						break;
					}
				}
			}
		}

		ArrangePerformers();

		sync = new SystemTimer;
	}

	~this()
	{
		Release();
	}

	void ArrangePerformers()
	{
		if (performers.length == 0)
			return;

		// TODO: arrange the performers to best utilise the available screen space...
		//... this is kinda hard!

		// HACK: just arrange horizontally for now...
		MFRect r = void;
		MFDisplay_GetDisplayRect(&r);
		r.width /= performers.length;
		foreach (i, p; performers)
		{
			p.screenSpace = r;
			p.screenSpace.x += i*r.width;
		}
	}

	void Begin()
	{
		song.pause(false);
		startTime = sync.now;

		foreach (p; performers)
			p.Begin(sync);
	}

	void Pause(bool bPause)
	{
		if (bPause && !bPaused)
		{
			song.pause(true);
			pauseTime = sync.now;
			bPaused = true;
		}
		else if (!bPause && bPaused)
		{
			song.pause(false);
			startTime += sync.now - pauseTime;
			bPaused = false;
		}
	}

	void Release()
	{
		foreach (p; performers)
			p.End();
		performers = null;

		if (song)
			song.release();
		song = null;
	}

	void Update()
	{
		if (!bPaused)
		{
			time = sync.now - startTime;

			foreach (p; performers)
				p.Update(time);
		}
	}

	void Draw()
	{
		MFView_Push();

		// TODO: draw the background
		Renderer.instance.SetCurrentLayer(RenderLayers.Background);

		// draw the tracks
		Renderer.instance.SetCurrentLayer(RenderLayers.Game);
		foreach (p; performers)
			p.Draw(time + (-Game.instance.settings.audioLatency + Game.instance.settings.videoLatency)*1_000);

		// draw the UI
		Renderer.instance.SetCurrentLayer(RenderLayers.UI);

		MFRect rect = MFRect(0, 0, 1920, 1080);
		MFView_SetOrtho(&rect);

		foreach (p; performers)
			p.DrawUI();

		MFView_Pop();
	}

	Song* song;
	Performer[] performers;
	SyncSource sync;
	long time;
	long startTime;
	long pauseTime;
	bool bPaused;

	mixin Signal!() beginMusic;		// ()
	mixin Signal!() endMusic;		// ()
}
