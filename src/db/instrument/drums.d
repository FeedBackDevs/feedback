module db.instrument.drums;

import db.inputs.inputdevice;
import db.instrument;
import db.tools.log;

enum TypeName = "drums";
enum Parts = [ "drums" ];
enum ScoreKeeper = "basicscorekeeper";

enum DrumFeatures
{
	Has4Drums,
	HasAnyCymbals,
	Has2Cymbals,
	Has3Cymbals,
	HasHiHat,
	HasHiHatPedal,
	HasRims,
	HasRideBell,
	HasVelocity
}

enum DrumInput
{
	Snare,
	Cymbal1,
	Tom1,
	Cymbal2,
	Tom2,
	Cymbal3,
	Tom3,
	Kick,
	Hat,

	SnareRim = Snare | Secondary,
	Tom1Rim = Tom1 | Secondary,
	Tom2Rim = Tom2 | Secondary,
	RideBell = Cymbal3 | Secondary,
	Tom3Rim = Tom3 | Secondary,
	OpenHat = Hat | Secondary,

	Secondary = 0x10,	// rims for drums, bell for cymbals, open for hat
}

enum DrumNotes
{				// RB kit		GH kit
	Hat,		//   Y			  Y
	Snare,		//   R			  R
	Crash,		//   B			  Y(/O?)
	Tom1,		//   Y			  B
	Tom2,		//   B			  B(/G?)
	Splash,		//   B/G?		  (Y?/)O
	Tom3,		//   G			  G
	Ride,		//   G			  O
	Kick,
//	Cowbell,	// cowbell or tambourine
}

enum DrumNoteFlags
{
	DoubleKick,	// double kick notes are hidden in single-kick mode
	OpenHat,	// interesting if drum kit has a hat pedal
	RimShot,	// if drums have rims
	CymbalBell,	// if cymbals have zones
}

class Drums : Instrument
{
	this(InputDevice device, uint features)
	{
		super(&descriptor, device, features);
	}

	override void update()
	{
		import fuji.fuji : MFBit;
		import fuji.input;
		import fuji.midi;
		import fuji.system : MFSystem_GetRTCFrequency;
		import db.game : Game;
		import db.inputs.controller : Controller;
		import db.inputs.midi : Midi;

		super.update();

		Controller c = cast(Controller)device;
		if (c && c.device.device == MFInputDevice.Gamepad)
		{
			ulong rtcFreq = MFSystem_GetRTCFrequency();

			// read midi stream, populate events
			MFInputEvent[64] buffer;
			MFInputEvent[] events;
			while ((events = c.getEvents(buffer[])) != null)
			{
				foreach (ref e; events)
				{
					// we only care about trigger events...
					if (e.event == MFInputEventType.Change)
					{
						InputEvent ie;
						ie.timestamp = (e.timestamp - c.startTime) * 1_000_000 / rtcFreq - (c.deviceLatency + Game.instance.settings.controllerLatency)*1_000;
						ie.key = e.input;
						ie.velocity = e.state;

						if (e.state && !e.prevState)
							ie.event = InputEventType.On;
						else if (e.prevState && !e.state)
							ie.event = InputEventType.Off;
						else
							ie.event = InputEventType.Change;

						// TODO: we probably want to apply some map to 'note' for the configured instrument type

						// map drums buttons -> 0-7
						switch (e.input) with(MFGamepadButton)
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

						stream ~= ie;

//						WriteLog(format("%6d input %s: %s (%g)", ie.timestamp/1000, to!string(ie.event), to!string(cast(DrumInput)ie.key), ie.velocity), MFVector(1,1,1,1));
					}
				}
			}
		}

		Midi m = cast(Midi)device;
		if (m)
		{
			// read midi stream, populate events
			MFMidiEvent[64] buffer;
			MFMidiEvent[] events;
			do
			{
				events = m.getEvents(buffer[]);

				foreach (ref e; events)
				{
					// we only care about trigger events...
					if (e.ev <= MFMidiEventType.NoteAftertouch)
					{
						InputEvent ie;
						ie.timestamp = cast(long)e.timestamp * 1_000 - (m.deviceLatency + Game.instance.settings.midiLatency)*1_000; // feedback times are microseconds
						ie.event = (e.ev == MFMidiEventType.NoteOff || (e.ev == MFMidiEventType.NoteOn && e.noteOn.velocity == 0)) ? InputEventType.Off : (e.ev == MFMidiEventType.NoteOn ? InputEventType.On : InputEventType.Change);
						ie.key = e.noteOn.note;
						ie.velocity = e.noteOn.velocity * (1 / 127.0f);

						// TODO: we probably want to apply some note map for the configured instrument type

						switch (e.noteOn.note)
						{
							case 46:
							case 26:	ie.key = DrumInput.Hat;
										if (pedalState < 0.5)
											ie.key |= DrumInput.Secondary;
										break;
							case 44:	ie.key = DrumInput.Hat;		break;	// pedal hi-hat
							case 35:										// From the Midi CH10 standard
							case 36:	ie.key = DrumInput.Kick;	break;
							case 38:	ie.key = DrumInput.Snare;	break;
							case 40:	ie.key = DrumInput.Snare | DrumInput.Secondary;	break;
							case 48:	ie.key = DrumInput.Tom1;	break;
							case 50:	ie.key = DrumInput.Tom1 | DrumInput.Secondary;	break;
							case 45:	ie.key = DrumInput.Tom2;	break;
							case 47:	ie.key = DrumInput.Tom2 | DrumInput.Secondary;	break;
							case 43:	ie.key = DrumInput.Tom3;	break;
							case 58:	ie.key = DrumInput.Tom3 | DrumInput.Secondary;	break;
							case 49:
							case 55:	ie.key = DrumInput.Cymbal1;	break;
							case 57:										// From the Midi CH10 standard
							case 52:	ie.key = DrumInput.Cymbal2;	break;	// From the Midi CH10 standard
							case 51:
							case 59:	ie.key = DrumInput.Cymbal3;	break;
							case 53:	ie.key = DrumInput.Cymbal3 | DrumInput.Secondary;	break;
							default:
								break;
						}

						stream ~= ie;

//						WriteLog(format("%6d input %s: %s (%g)", ie.timestamp/1000, to!string(ie.event), to!string(cast(DrumInput)ie.key), ie.velocity), MFVector(1,1,1,1));
					}
					else if (e.ev == MFMidiEventType.ControlChange)
					{
						switch (e.controlChange.control)
						{
							case 0x04:
								pedalState = e.controlChange.value * (1 / 127.0f);
								break;
							default:
								break;
						}
						// TODO: trigger a hat hit if pedal depressed quickly?
					}
				}
			}
			while (events.length == buffer.length);
		}
	}

private:
	float pedalState;
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
	return new Drums(device, features);
}

Instrument detectInstrument(InputDevice device)
{
	import fuji.fuji : MFBit;
	import fuji.input;
	import db.inputs.controller;
	import db.inputs.midi;

	Controller c = cast(Controller)device;
	if (c)
	{
		// detect instrument type... (we have a database of USB id's for various music game controllers)
		uint flags = c.deviceFlags;

		if ((flags & MFGamepadFlags.TypeMask) == MFGamepadFlags.Type_Drums)
		{
			uint features;

			// Note: I think the most we can detect from the USB id's is whether it's meant for GH or RB (??)
			features |= flags & MFGamepadFlags.Drums_Has5Drums ? MFBit!(DrumFeatures.Has2Cymbals) : MFBit!(DrumFeatures.Has4Drums);

			// TODO: is it possible to detect RockBand drums with the cymbals attached?
			// Probably not, we'll probably need to offer UI to specialise the options...
//			if (rbDrums)
//				features |= MFBit!(DrumFeatures.Has3Cymbals);

			if (features & (MFBit!(DrumFeatures.Has2Cymbals) | MFBit!(DrumFeatures.Has3Cymbals)))
				features |= MFBit!(DrumFeatures.HasAnyCymbals);

			return new Drums(device, features);
		}
	}

	Midi m = cast(Midi)device;
	if (m)
	{
		if (m.vendor == 0x410000 && m.family == 0x012D && m.member == 0x0000)
		{
			m.setDeviceName("Roland TD-9");

			uint features = MFBit!(DrumFeatures.Has4Drums) | MFBit!(DrumFeatures.Has2Cymbals) | MFBit!(DrumFeatures.HasHiHat);

			// TODO: can we detect the presence of the 3rd cymbal or 5th drum?
			// sysex request?

			return new Drums(device, features);
		}
	}

	return null;
}

immutable InstrumentDesc descriptor = InstrumentDesc(TypeName, Parts, ScoreKeeper, &createInstrument, &detectInstrument);
