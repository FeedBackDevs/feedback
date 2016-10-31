module db.instrument.drums;

import db.instrument;

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
	HatPedal,

	Secondary = 0x10,	// rims for drums, bell for cymbals
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


package:

void registerType()
{
	registerInstrumentType(desc);
}


private:

import db.inputs.inputdevice : InputDevice;

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
		uint flags = MFInput_GetDeviceFlags(c.device, c.deviceId);

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

			return new Instrument(&desc, device, features);
		}
	}

	Midi m = cast(Midi)device;
	if (m)
	{
		if (m.vendor == 0x410000 && m.family == 0x012D && m.member == 0x0000)
		{
			m.setDeviceName("Roland TD-9");

			uint features = MFBit!(DrumFeatures.Has4Drums) | MFBit!(DrumFeatures.Has2Cymbals) | MFBit!(DrumFeatures.HasHiHat);

			return new Instrument(&desc, device, features);
		}
	}

	return null;
}

immutable InstrumentDesc desc = InstrumentDesc(TypeName, Parts, ScoreKeeper, &detectInstrument);
