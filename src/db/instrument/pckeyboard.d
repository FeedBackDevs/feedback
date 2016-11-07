module db.instrument.pckeyboard;

import db.inputs.inputdevice;
import db.instrument;
import db.tools.log;

enum TypeName = "pckeyboard";
enum Parts = [ "leadguitar", "rhythmguitar", "bass", "drums", "keyboard", "dance", "beatmania" ];
enum ScoreKeeper = "basicscorekeeper";

class PcKeyboard : Instrument
{
	this(InputDevice device, uint features)
	{
		super(&descriptor, device, features);
	}

	override void Update()
	{
		import fuji.input;
		import fuji.system : MFSystem_GetRTCFrequency;
		import db.game : Game;
		import db.inputs.controller : Controller;

		super.Update();

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
					ie.velocity = e.state;

					// apply a keymap appropriate for the part...

					if (part[] == "dance")
					{
						import db.instrument.dance;
						switch (e.input)
						{
							case MFKey.Up:		ie.key = DanceNotes.Up;			break;
							case MFKey.Down:	ie.key = DanceNotes.Down;		break;
							case MFKey.Left:	ie.key = DanceNotes.Left;		break;
							case MFKey.Right:	ie.key = DanceNotes.Right;		break;
							case MFKey.NumPad7:	ie.key = DanceNotes.UpLeft;		break;
							case MFKey.NumPad8:	ie.key = DanceNotes.Up;			break;
							case MFKey.NumPad9:	ie.key = DanceNotes.UpRight;	break;
							case MFKey.NumPad4:	ie.key = DanceNotes.Left;		break;
							case MFKey.NumPad5:	ie.key = DanceNotes.Center;		break;
							case MFKey.NumPad6:	ie.key = DanceNotes.Right;		break;
							case MFKey.NumPad1:	ie.key = DanceNotes.DownLeft;	break;
							case MFKey.NumPad2:	ie.key = DanceNotes.Down;		break;
							case MFKey.NumPad3:	ie.key = DanceNotes.DownRight;	break;

							// TODO: parse variation string, map numbers to dance/pump properly
							case MFKey._1:		ie.key = DanceNotes.Left;		break;
							case MFKey._2:		ie.key = DanceNotes.Down;		break;
							case MFKey._3:		ie.key = DanceNotes.Up;			break;
							case MFKey._4:		ie.key = DanceNotes.Right;		break;
							case MFKey._5:		ie.key = DanceNotes.Left2;		break;
							case MFKey._6:		ie.key = DanceNotes.Down2;		break;
							case MFKey._7:		ie.key = DanceNotes.Up2;		break;
							case MFKey._8:		ie.key = DanceNotes.Right2;		break;
							default:
								ie.velocity = 0;
								break;
						}
					}

					if (e.state && !e.prevState)
						ie.event = InputEventType.On;
					else if (e.prevState && !e.state)
						ie.event = InputEventType.Off;
					else
						ie.event = InputEventType.Change;

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
	return new PcKeyboard(device, features);
}

Instrument detectInstrument(InputDevice device)
{
	import fuji.fuji : MFBit;
	import fuji.input;
	import db.inputs.controller;

	Controller c = cast(Controller)device;
	if (c && c.device.device == MFInputDevice.Keyboard)
	{
		return new PcKeyboard(device, 0);
	}
	return null;
}

immutable InstrumentDesc descriptor = InstrumentDesc(TypeName, Parts, ScoreKeeper, &createInstrument, &detectInstrument);
