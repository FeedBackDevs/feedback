module db.inputs.audio;

import db.tools.log;
import db.i.inputdevice;
import db.instrument;
import db.game;

class Audio : InputDevice
{
	this(int audioDeviceId)
	{
		deviceId = audioDeviceId;

		// this is either vocals, or pro-guitar
	}

	override @property long inputTime()
	{
		return Game.instance.performance.time - (deviceLatency + Game.instance.settings.micLatency)*1_000;
	}

	override void Update()
	{
		// read audio stream, process into input sequence...

		// vox and guitar require different filtering
	}

	int deviceId;
}
