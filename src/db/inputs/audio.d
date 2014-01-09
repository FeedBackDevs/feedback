module db.inputs.audio;

import db.i.inputdevice;
import db.instrument;

class Audio : InputDevice
{
	this(int audioDeviceId)
	{
		deviceId = audioDeviceId;

		// this is either vocals, or pro-guitar
	}

	@property InstrumentType instrumentType() { return instrument; }
	@property InputEvent[] events() { return stream; }

	void Update()
	{
		// read audio stream, process into input sequence...

		// vox and guitar require different filtering
	}

	void Clear(long until)
	{
		// clear all events before 'until'
	}

	int deviceId;
	InstrumentType instrument;
	InputEvent[] stream;
}
