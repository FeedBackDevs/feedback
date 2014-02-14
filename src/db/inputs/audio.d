module db.inputs.audio;

import db.tools.log;
import db.i.inputdevice;
import db.instrument;

class Audio : InputDevice
{
	this(int audioDeviceId)
	{
		deviceId = audioDeviceId;

		// this is either vocals, or pro-guitar
	}

	override void Update()
	{
		// read audio stream, process into input sequence...

		// vox and guitar require different filtering
	}

	int deviceId;
}
