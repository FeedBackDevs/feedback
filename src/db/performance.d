module db.performance;

import fuji.display;

import db.instrument;
import db.song;
import db.sequence;
import db.player;
import db.renderer;

import db.i.inputdevice;
import db.i.notetrack;
import db.i.scorekeeper;
import db.i.syncsource;

import db.tracks.gh_drums;
import db.scorekeepers.drums;
import db.sync.systime;

class Performer
{
	this(Performance performance, Player player, Sequence sequence)
	{
		this.performance = performance;
		this.player = player;
		this.sequence = sequence;

		// HACK: hardcoded classes for the moment...
		// Note: note track should be chosen accorting to the instrument type, and player preference for theme/style (GH/RB/Bemani?)
		if(player.input.part == Part.Drums)
		{
			noteTrack = new GHDrums(performance.song);
			scoreKeeper = new DrumsScoreKeeper(sequence, player.input.device);
		}
	}

	void Begin(SyncSource sync)
	{
		scoreKeeper.Begin(sync);
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
		noteTrack.Draw(screenSpace, now, this);
	}

	MFRect screenSpace;
	Performance performance;
	Player player;
	Sequence sequence;
	NoteTrack noteTrack;
	ScoreKeeper scoreKeeper;
}

class Performance
{
	this(Song song, Player[] players)
	{
		this.song = song;
		song.Prepare();

		// create and arrange the performers for 'currentSong'
		// Note: Players whose parts are unavailable in the song will not have performers created
		performers = null;
		foreach(p; players)
		{
			if(song.IsPartPresent(p.input.part))
				performers ~= new Performer(this, p, song.variations[p.input.part][0].difficulties.back);
		}

		ArrangePerformers();

		sync = new SystemTimer;
	}

	~this()
	{
		song.Release();
	}

	void ArrangePerformers()
	{
		if(performers.length == 0)
			return;

		// TODO: arrange the performers to best utilise the available screen space...
		//... this is kinda hard!

		// HACK: just arrange horizontally for now...
		MFRect r = void;
		MFDisplay_GetNativeRes(&r);
		r.width /= performers.length;
		foreach(i, p; performers)
		{
			p.screenSpace = r;
			p.screenSpace.x += i*r.width;
		}
	}

	void Begin()
	{
		song.Pause(false);
		startTime = sync.now;

		foreach(p; performers)
			p.Begin(sync);
	}

	void End()
	{
		foreach(p; performers)
			p.End();
	}

	void Update()
	{
		time = sync.now - startTime;

		foreach(p; performers)
			p.Update(time);
	}

	void Draw()
	{
		// TODO: draw the background
		Renderer.Instance.SetCurrentLayer(RenderLayers.Background);

		// draw the players
		Renderer.Instance.SetCurrentLayer(RenderLayers.Game);
		foreach(p; performers)
			p.Draw(time);
	}

	Song song;
	Performer performers[];
	SyncSource sync;
	long startTime;
	long time;
}
