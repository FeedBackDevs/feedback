module db.instrument.guitarcontroller;

import db.instrument;

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

	Controller c = cast(Controller)device;
	if (c)
	{
		// detect instrument type... (we have a database of USB id's for various music game controllers)
		uint flags = MFInput_GetDeviceFlags(c.device, c.deviceId);

		if ((flags & MFGamepadFlags.TypeMask) == MFGamepadFlags.Type_Guitar)
		{
			uint features;
			features |= flags & MFGamepadFlags.Guitar_HasTilt ? MFBit!(GuitarFeatures.HasTilt) : 0;
			features |= flags & MFGamepadFlags.Guitar_HasSolo ? MFBit!(GuitarFeatures.HasSolo) : 0;
			features |= flags & MFGamepadFlags.Guitar_HasSlider ? MFBit!(GuitarFeatures.HasSlider) : 0;
			features |= flags & MFGamepadFlags.Guitar_HasPickupSwitch ? MFBit!(GuitarFeatures.HasPickupSwitch) : 0;
			return new Instrument(&desc, device, features);
		}
	}
	return null;
}

immutable InstrumentDesc desc = InstrumentDesc(TypeName, Parts, ScoreKeeper, &detectInstrument);
