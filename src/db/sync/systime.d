module db.sync.systime;

import fuji.system;

import db.i.syncsource;

class SystemTimer : SyncSource
{
	this()
	{
		freq = MFSystem_GetRTCFrequency();
	}

	override @property long clock()
	{
		return MFSystem_ReadRTC();
	}

	override @property long resolution()
	{
		return freq;
	}

	long freq;
}
