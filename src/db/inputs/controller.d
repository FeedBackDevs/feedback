module db.inputs.controller;

import db.tools.log;
import db.inputs.inputdevice;
import db.i.syncsource;
import db.instrument;
import db.chart.track : Track;
import db.game;

import fuji.fuji;
import fuji.system;
import fuji.input;

class Controller : db.inputs.inputdevice.InputDevice
{
	this(MFInputDevice device, int deviceId)
	{
		this.device = fuji.input.InputDevice(device, deviceId);
	}

	override @property const(char)[] name() const
	{
		return device.name;
	}

	override @property long inputTime() const
	{
		return Game.instance.performance.time - (deviceLatency + Game.instance.settings.controllerLatency)*1_000;
	}

	@property uint deviceFlags() const { return device.deviceFlags; }

	bool isDevice(MFInputDevice device, int deviceId) const
	{
		return this.device.device == device && this.device.deviceID == deviceId;
	}

	override void Begin(SyncSource sync)
	{
		super.Begin(sync);

		startTime = MFSystem_ReadRTC();
	}

	MFInputEvent[] getEvents(MFInputEvent[] eventBuffer)
	{
		return device.getInputEvents(eventBuffer);
	}

	ulong startTime;
	bool bCantDetectFeatures;

	fuji.input.InputDevice device;
}
