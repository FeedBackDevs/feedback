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

class Controller : InputDevice
{
	this(MFInputDevice device, int deviceId)
	{
		this.device = device;
		this.deviceId = deviceId;
	}

	override @property const(char)[] name() const
	{
		return MFInput_GetDeviceName(device, deviceId);
	}

	override @property long inputTime() const
	{
		return Game.instance.performance.time - (deviceLatency + Game.instance.settings.controllerLatency)*1_000;
	}

	override void Begin(SyncSource sync)
	{
		super.Begin(sync);

		startTime = MFSystem_ReadRTC();
	}

	override void Update()
	{
		ulong rtcFreq = MFSystem_GetRTCFrequency();

		// read midi stream, populate events
		MFInputEvent[64] buffer;
		MFInputEvent[] events;
		while ((events = MFInput_GetEvents(device, deviceId, buffer[])) != null)
		{
			foreach (ref e; events)
			{
				// we only care about trigger events...
				if (e.event == MFInputEventType.Change)
				{
					InputEvent ie;
					ie.timestamp = (e.timestamp - startTime) * 1_000_000 / rtcFreq - (deviceLatency + Game.instance.settings.controllerLatency)*1_000;
					ie.key = e.input;
					ie.velocity = e.state;

					if (e.state && !e.prevState)
						ie.event = InputEventType.On;
					else if (e.prevState && !e.state)
						ie.event = InputEventType.Off;
					else
						ie.event = InputEventType.Change;

//					// TODO: we probably want to apply some map to 'note' for the configured instrument type
//					if (instrumentType == InstrumentType.GuitarController)
//					{
//						// map guitar buttons -> 0-4
//						switch (e.input) with(MFGamepadButton)
//						{
//							case GH_Green:			ie.key = GuitarInput.Green;				break;
//							case GH_Red:			ie.key = GuitarInput.Red;				break;
//							case GH_Yellow:			ie.key = GuitarInput.Yellow;			break;
//							case GH_Blue:			ie.key = GuitarInput.Blue;				break;
//							case GH_Orange:			ie.key = GuitarInput.Orange;			break;
//							case GH_Whammy:			ie.key = GuitarInput.Whammy;			break;
//							case GH_Tilt:			ie.key = GuitarInput.Tilt;				break;
//							case GH_TiltTrigger:	ie.key = GuitarInput.TriggerSpecial;	break;
//							case GH_StrumUp: ..
//							case GH_StrumDown:		ie.key = GuitarInput.Strum;				break;
////							GH_Roll:
////							GH_PickupSwitch:
////							GH_Slider:
////							GH_Solo:
//							default:
//								continue;
//						}
//					}
//					else if (instrumentType == InstrumentType.Drums)
//					{
//						// map drums buttons -> 0-7
//						switch (e.input) with(MFGamepadButton)
//						{
//							case Drum_Red:		ie.key = DrumInput.Snare;		break;
//							case Drum_Yellow:	ie.key = !(features & MFBit!(DrumFeatures.Has4Drums)) ? DrumInput.Cymbal1 : DrumInput.Tom1;		break;
//							case Drum_Blue:		ie.key = DrumInput.Tom2;		break;
//							case Drum_Green:	ie.key = DrumInput.Tom3;		break;
//							case Drum_Cymbal:	ie.key = DrumInput.Cymbal3;		break;
//							case Drum_Kick:		ie.key = DrumInput.Kick;		break;
//							default:
//								continue;
//						}
//					}
//					else if (device == MFInputDevice.Keyboard)
//					{
//						// TODO: map keys to something sensible...
//					}

					stream ~= ie;

//					WriteLog(format("%6d input %s: %d (%g)", ie.timestamp/1000, to!string(ie.event), ie.key, ie.velocity), MFVector(1,1,1,1));
				}
			}
		}
	}

	MFInputDevice device;
	int deviceId;
	bool bCantDetectFeatures;

	ulong startTime;
}
