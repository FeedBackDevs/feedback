module db.instrument.guitarcontroller;

import db.inputs.inputdevice;
import db.instrument;
import db.tools.log;

enum TypeName = "guitarcontroller";
enum Parts = [ "leadguitar", "rhythmguitar", "bass" ];
enum ScoreKeeper = "basicscorekeeper";

enum GuitarFeatures
{
	HasTilt,
	HasSolo,
	HasSlider,
	HasPickupSwitch
}

enum GuitarInput
{
	Green,
	Red,
	Yellow,
	Blue,
	Orange,
	Strum,
	Whammy,
	Tilt,
	TriggerSpecial,
	Switch,

	Solo = 0x10,
	Slider = 0x20,
}

enum GuitarNotes
{
	Green,
	Red,
	Yellow,
	Blue,
	Orange,
	Open
}

enum GuitarNoteFlags
{
	HOPO,			// hammer-on/pull-off
	Tap,			// tap note

	// these are only for 'real' guitar
	Slide,			// slide
	Mute,			// palm muting
	Harm,			// harmonic
	ArtificialHarm	// artificial harmonic
}

class GuitarController : Instrument
{
	this(InputDevice device, uint features)
	{
		super(&descriptor, device, features);
	}

	override void update()
	{
		import fuji.input;
		import fuji.system : MFSystem_GetRTCFrequency;
		import db.game : Game;
		import db.inputs.controller : Controller;

		super.update();

		ulong rtcFreq = MFSystem_GetRTCFrequency();

		Controller controller = cast(Controller)device;
		assert(controller);

		// read midi stream, populate events
		MFInputEvent[64] buffer;
		MFInputEvent[] events;
		while ((events = controller.getEvents(buffer[])) != null)
		{
			foreach (ref e; events)
			{
				// we only care about trigger events...
				if (e.event == MFInputEventType.Change)
				{
					InputEvent ie;
					ie.timestamp = (e.timestamp - controller.startTime) * 1_000_000 / rtcFreq - (controller.deviceLatency + Game.instance.settings.controllerLatency)*1_000;
					ie.key = e.input;
					ie.velocity = e.state;

					if (e.state && !e.prevState)
						ie.event = InputEventType.On;
					else if (e.prevState && !e.state)
						ie.event = InputEventType.Off;
					else
						ie.event = InputEventType.Change;

					// TODO: we probably want to apply some map to 'note' for the configured instrument type

					// map guitar buttons -> 0-4
					switch (e.input) with(MFGamepadButton)
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

					stream ~= ie;

//					WriteLog(format("%6d input %s: %s (%g)", ie.timestamp/1000, to!string(ie.event), to!string(cast(GuitarInput)ie.key), ie.velocity), MFVector(1,1,1,1));
				}
			}
		}
	}
}


package:

void registerType()
{
	registerInstrumentType(descriptor);
}


private:

import db.inputs.inputdevice : InputDevice;

Instrument createInstrument(InputDevice device, uint features)
{
	return new GuitarController(device, features);
}

Instrument detectInstrument(InputDevice device)
{
	import fuji.fuji : MFBit;
	import fuji.input;
	import db.inputs.controller;

	Controller c = cast(Controller)device;
	if (c && c.device.device == MFInputDevice.Gamepad)
	{
		// detect instrument type... (we have a database of USB id's for various music game controllers)
		uint flags = c.deviceFlags;

		if ((flags & MFGamepadFlags.TypeMask) == MFGamepadFlags.Type_Guitar)
		{
			uint features;
			features |= flags & MFGamepadFlags.Guitar_HasTilt ? MFBit!(GuitarFeatures.HasTilt) : 0;
			features |= flags & MFGamepadFlags.Guitar_HasSolo ? MFBit!(GuitarFeatures.HasSolo) : 0;
			features |= flags & MFGamepadFlags.Guitar_HasSlider ? MFBit!(GuitarFeatures.HasSlider) : 0;
			features |= flags & MFGamepadFlags.Guitar_HasPickupSwitch ? MFBit!(GuitarFeatures.HasPickupSwitch) : 0;
			return new GuitarController(device, features);
		}
	}
	return null;
}

immutable InstrumentDesc descriptor = InstrumentDesc(TypeName, Parts, ScoreKeeper, &createInstrument, &detectInstrument);
