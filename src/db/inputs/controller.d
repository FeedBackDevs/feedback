module db.inputs.controller;

import db.tools.log;
import db.i.inputdevice;
import db.i.syncsource;
import db.instrument;
import db.game;

import fuji.fuji;
import fuji.system;
import fuji.input;

class Controller : InputDevice
{
	this(int controllerId)
	{
		this.controllerId = controllerId;

		// detect instrument type... (we have a database of USB id's for various music game controllers)
		uint flags = MFInput_GetDeviceFlags(MFInputDevice.Gamepad, controllerId);

		// instruments attached via adapters or proxy drivers can't be detected...
		if(flags & (MFGamepadFlags.IsAdapter | MFGamepadFlags.IsProxy))
			bCantDetectFeatures = true;

		if((flags & MFGamepadFlags.TypeMask) == MFGamepadFlags.Type_Guitar)
		{
			instrumentType = InstrumentType.GuitarController;

			features |= flags & MFGamepadFlags.Guitar_HasTilt ? MFBit!(GuitarFeatures.HasTilt) : 0;
			features |= flags & MFGamepadFlags.Guitar_HasSolo ? MFBit!(GuitarFeatures.HasSolo) : 0;
			features |= flags & MFGamepadFlags.Guitar_HasSlider ? MFBit!(GuitarFeatures.HasSlider) : 0;
			features |= flags & MFGamepadFlags.Guitar_HasPickupSwitch ? MFBit!(GuitarFeatures.HasPickupSwitch) : 0;
		}

		if((flags & MFGamepadFlags.TypeMask) == MFGamepadFlags.Type_Drums)
		{
			instrumentType = InstrumentType.Drums;

			// Note: I think the most we can detect from the USB id's is whether it is meant for GH or RB
			features |= flags & MFGamepadFlags.Drums_Has5Drums ? MFBit!(DrumFeatures.Has2Cymbals) : MFBit!(DrumFeatures.Has4Drums);

			// TODO: is it possible to detect RockBand drums with the cymbals attached?
			// Probably not, we'll probably need to offer UI to specialise the options...
//			if(rbDrums)
//				features |= MFBit!(DrumFeatures.Has3Cymbals);

			features = MFBit!(DrumFeatures.Has3Cymbals) | MFBit!(DrumFeatures.Has4Drums) | MFBit!(DrumFeatures.HasHiHat);

			if(features & (MFBit!(DrumFeatures.Has2Cymbals) | MFBit!(DrumFeatures.Has3Cymbals)))
				features |= MFBit!(DrumFeatures.HasAnyCymbals);
		}

		// TODO: detect other types of controllers from other games...
	}

	override @property long inputTime()
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
		while((events = MFInput_GetEvents(MFInputDevice.Gamepad, controllerId, buffer[])) != null)
		{
			foreach(e; events)
			{
				// we only care about trigger events...
				if(e.event == MFInputEventType.Change)
				{
					InputEvent ie;
					ie.timestamp = (e.timestamp - startTime) * 1_000_000 / rtcFreq - (deviceLatency + Game.instance.settings.controllerLatency)*1_000;
					ie.key = e.input;
					ie.velocity = e.state;

					if(e.state && !e.prevState)
						ie.event = InputEventType.On;
					else if(e.prevState && !e.state)
						ie.event = InputEventType.Off;
					else
						ie.event = InputEventType.Change;

					// TODO: we probably want to apply some map to 'note' for the configured instrument type
					if(instrumentType == InstrumentType.GuitarController)
					{
						// map guitar buttons -> 0-4
						switch(e.input) with(MFGamepadButton)
						{
							case GH_Green:			ie.key = GuitarInput.Green;				break;
							case GH_Red:			ie.key = GuitarInput.Red;				break;
							case GH_Yellow:			ie.key = GuitarInput.Yellow;			break;
							case GH_Blue:			ie.key = GuitarInput.Blue;				break;
							case GH_Orange:			ie.key = GuitarInput.Orange;			break;
							case GH_Whammy:			ie.key = GuitarInput.Whammy;			break;
							case GH_Tilt:			ie.key = GuitarInput.Tilt;				break;
							case GH_TiltTrigger:	ie.key = GuitarInput.TriggerSpecial;	break;
							case GH_StrumUp: ..
							case GH_StrumDown:		ie.key = GuitarInput.Strum;				break;
//							GH_Roll:
//							GH_PickupSwitch:
//							GH_Slider:
//							GH_Solo:
							default:
								continue;
						}
					}
					else if(instrumentType == InstrumentType.Drums)
					{
						// map drums buttons -> 0-7
						switch(e.input) with(MFGamepadButton)
						{
							case Drum_Red:		ie.key = DrumInput.Snare;		break;
							case Drum_Yellow:	ie.key = !(features & MFBit!(DrumFeatures.Has4Drums)) ? DrumInput.Cymbal1 : DrumInput.Tom1;		break;
							case Drum_Blue:		ie.key = DrumInput.Tom2;		break;
							case Drum_Green:	ie.key = DrumInput.Tom3;		break;
							case Drum_Cymbal:	ie.key = DrumInput.Cymbal3;		break;
							case Drum_Kick:		ie.key = DrumInput.Kick;		break;
							default:
								continue;
						}
					}

					stream ~= ie;

//					WriteLog(format("%6d input %s: %d (%g)", ie.timestamp/1000, to!string(ie.event), ie.key, ie.velocity), MFVector(1,1,1,1));
				}
			}
		}
	}

	int controllerId;
	bool bCantDetectFeatures;

	ulong startTime;
}

Controller[] detectControllers()
{
	Controller[] controllers;

	foreach(i; 0..MFInput_GetNumGamepads())
		controllers ~= new Controller(i);

	return controllers;
}
