module db.inputs.inputdevice;

import db.i.syncsource : SyncSource;
import db.instrument : Instrument;

import luad.base : noscript;

class InputDevice
{
	long deviceLatency;

	abstract @property const(char)[] name() const;

	abstract @property long inputTime() const;

@noscript:

	void Begin(SyncSource sync)
	{
		this.sync = sync;
	}

	void End()
	{
	}

	void Update()
	{
		// NOTE: may be run on a high-frequency thread
	}

	Instrument instrument;
	SyncSource sync;
}
