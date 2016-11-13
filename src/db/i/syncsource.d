module db.i.syncsource;

class SyncSource
{
	@property long now() { return ((pauseTime ? pauseTime : clock) - resetTime)*1_000_000 / resolution; }

	@property double seconds() { return cast(double)((pauseTime ? pauseTime : clock) - resetTime) / resolution; }
	@property void seconds(double s)
	{
		reset(cast(long)(s * 1_000_000));
	}

	void reset(long usecs = 0)
	{
		long c = clock;
		resetTime = c - (usecs * resolution / 1_000_000);
		if (pauseTime)
			pauseTime = c;
	}

	void pause(bool paused)
	{
		if (paused && !pauseTime)
		{
			pauseTime = clock;
		}
		else if(!paused && pauseTime)
		{
			resetTime += clock - pauseTime;
			pauseTime = 0;
		}
	}

	abstract @property long clock();
	abstract @property long resolution();

	long resetTime;
	long pauseTime;
}
