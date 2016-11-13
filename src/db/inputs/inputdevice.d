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

	void begin()
	{
	}

	void end()
	{
	}

	void update()
	{
		// NOTE: may be run on a high-frequency thread
	}

	Instrument instrument;
}
