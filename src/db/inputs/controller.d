module db.inputs.controller;

import db.i.inputdevice;
import db.instrument;

import fuji.input;

enum ControllerFeatures : uint
{
	// general flags
	CantDetect = MFBit!0,

	// guitar stuff
	HasTilt = MFBit!1,
	HasSolo = MFBit!2,
	HasPickupSwitch = MFBit!3,
	HasSlider = MFBit!4,

	// drums stuff
	Has4Drums = MFBit!5,
	Has3Drums2Cymbals = MFBit!6,
	Has4Drums2Cymbals = MFBit!7,
	Has4Drums3Cymbals = MFBit!8,
	HasDoubleKick = MFBit!9,
}

class Controller : InputDevice
{
	this(int controllerId)
	{
		this.controllerId = controllerId;

		// detect instrument type... (we have a database of USB id's for various music game controllers)
		uint flags = MFInput_GetDeviceFlags(MFInputDevice.Gamepad, controllerId);

		// instruments attached via adapters or proxy drivers can't be detected...
		if(flags & (MFGamepadFlags.IsAdapter | MFGamepadFlags.IsProxy))
			features |= ControllerFeatures.CantDetect;

		if(flags & MFGamepadFlags.IsGuitar)
		{
			instrument = InstrumentType.GuitarController;

			features |= flags & MFGamepadFlags.Guitar_HasTilt ? ControllerFeatures.HasTilt : 0;
			features |= flags & MFGamepadFlags.Guitar_HasSolo ? ControllerFeatures.HasSolo : 0;
			features |= flags & MFGamepadFlags.Guitar_HasPickupSwitch ? ControllerFeatures.HasPickupSwitch : 0;
			features |= flags & MFGamepadFlags.Guitar_HasSlider ? ControllerFeatures.HasSlider : 0;
		}

		if(flags & MFGamepadFlags.IsDrums)
		{
			instrument = InstrumentType.Drums;

			// Note: I think the most we can detect from the USB id's is whether it is meant for GH or RB
			features |= flags & MFGamepadFlags.Drums_Has5Drums ? ControllerFeatures.Has3Drums2Cymbals : ControllerFeatures.Has4Drums;

			// TODO: is it possible to detect RockBand drums with the cymbals attached?
			// Probably not, we'll probably need to offer UI to specialise the options...
		}

		// TODO: detect other types of controllers from other games...
	}

	@property InstrumentType instrumentType() { return instrument; }
	@property InputEvent[] events() { return stream; }

	void Update()
	{
		// read controller, populate events
	}

	void Clear(long until)
	{
		// clear all events before 'until'
	}

	int controllerId;
	InstrumentType instrument;
	uint features;

	InputEvent[] stream;
}

Controller[] DetectControllers()
{
	Controller[] controllers;

	foreach(i; 0..MFInput_GetNumGamepads())
		controllers ~= new Controller(i);

	return controllers;
}
