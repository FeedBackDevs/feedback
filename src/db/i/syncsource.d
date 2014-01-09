module db.i.syncsource;

interface SyncSource
{
	@property long now();
	@property long resolution();
}
