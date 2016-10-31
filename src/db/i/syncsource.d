module db.i.syncsource;

class SyncSource
{
	@property long now() { return (clock - resetTime)*1_000_000 / resolution; }
	@property double seconds() { return cast(double)(clock - resetTime) / resolution; }

	void reset() { resetTime = clock; }

	abstract @property long clock();
	abstract @property long resolution();

	long resetTime;
}
