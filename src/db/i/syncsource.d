module db.i.syncsource;

class SyncSource
{
	@property long now() { return clock * 1000000 / resolution; }

	abstract @property long clock();
	abstract @property long resolution();
}
