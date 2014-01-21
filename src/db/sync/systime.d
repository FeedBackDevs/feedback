module db.sync.systime;

import fuji.system;

import db.i.syncsource;

class SystemTimer : SyncSource
{
	override @property long clock()
	{
		return MFSystem_ReadRTC();
	}

	override @property long resolution()
	{
		return MFSystem_GetRTCFrequency();
	}
}
