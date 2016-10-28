module db.ui.inputmanager;

import db.tools.event;
import db.player;

import fuji.fuji;
import fuji.input;
import fuji.display;

import luad.base : noscript;

import std.math : sqrt;

struct InputSource
{
	int sourceID;

	MFInputDevice device;
	int deviceID;

	// HAX: We often have const(InputSource), but we want 'player' to be mutable
	@property Player player() const { return cast(Player)_player; }
	@property void player(Player player) const { (cast(InputSource*)&this)._player = player; }
	private Player _player;
}

class InputManager
{
public:
	enum MaxSources = 64;

	enum EventType
	{
		// screen/mouse
		Down,
		Up,
		Cancel,
		Tap,
		Hover,
		Drag,
		Pinch,
		Spin,

		// buttons and keys
		ButtonTriggered,
		ButtonDown,
		ButtonUp,
		Axis,
		Character,
		Wheel
	}

	struct EventInfo
	{
		struct Hover
		{
			float x, y;
			float deltaX, deltaY;
		}
		struct Tap
		{
			float x, y;
			float holdLength;
		}
		struct Drag
		{
			float x, y;
			float deltaX, deltaY;
			float startX, startY;
		}
		struct Down
		{
			float x, y;
		}
		struct Up
		{
			float x, y;
			float downX, downY;
			float holdLength;
		}
		struct Pinch
		{
			float centerX, centerY;
			float deltaScale;
			int contact2;
		}
		struct Spin
		{
			float centerX, centerY;
			float deltaAngle;
			int contact2;
		}
		struct Axis
		{
			float x, y;
		}

		const(InputSource)* pSource;

		EventType ev;			// event

		int contact;			// for multiple-contact devices (multiple mice/multi-touch screens)
		int buttonID;			// button ID (always 0 for touch screens)

		union
		{
			Hover hover;
			Tap tap;
			Drag drag;
			Down down;
			Up up;
			Pinch pinch;
			Spin spin;
			Axis axis;
		}

	const: pure: nothrow: @safe:
		@property int sourceID() { return pSource.sourceID; }

		@property MFInputDevice device() { return pSource.device; }
		@property int deviceID() { return pSource.deviceID; }
	}

	alias InputEvent = Event!(InputManager, const(EventInfo)*);


	@property float dragThreshold() { return _dragThreshold; }
	@property void dragThreshold(float threshold) { _dragThreshold = threshold; }

	InputSource* findSource(MFInputDevice device, int deviceID = 0)
	{
		foreach(a; 0..numDevices)
		{
			if(sources[a].device == device && sources[a].deviceID == deviceID)
				return &sources[a];
		}
		return null;
	}

@noscript:
	this()
	{
		scanForDevices();
	}

	void update()
	{
		// search for new events
		foreach(a; 0..MaxSources)
		{
			if(sources[a].sourceID == -1)
				continue;

			MFInputDevice device = sources[a].device;
			int deviceID = sources[a].deviceID;

			if(device == MFInputDevice.Mouse)
			{
				if(mouseContacts[deviceID] == -1 && MFInput_IsReady(device, deviceID))
				{
					foreach(c; 0..MaxContacts)
					{
						if(!bCurrentContacts[c])
						{
							bCurrentContacts[c] = true;
							mouseContacts[deviceID] = c;

							// create the hover contact
							MFVector pos = correctPosition(MFInput_Read(MFMouseButton.XPos, device, deviceID), MFInput_Read(MFMouseButton.YPos, device, deviceID));
							contacts[c].init(&sources[a], -1, pos.x, pos.y);
							contacts[c].downX = contacts[c].downY = 0;

//							pNewContactCallback(c);
							break;
						}
					}
				}

				if(MFDisplay_HasFocus())
				{
					foreach(int b; 0..MFMouseButton.MaxButtons)
					{
						if(mouseButtonContacts[deviceID][b] == -1)
						{
							if(MFInput_Read(MFMouseButton.LeftButton + b, device, deviceID))
							{
								foreach(c; 0..MaxContacts)
								{
									if(!bCurrentContacts[c])
									{
										bCurrentContacts[c] = true;
										mouseButtonContacts[deviceID][b] = c;

										contacts[c].init(&sources[a], b + MFMouseButton.LeftButton, contacts[mouseContacts[deviceID]].x, contacts[mouseContacts[deviceID]].y);
										contacts[c].bState = true;

//										pNewContactCallback(c);

										// send the down event
										EventInfo info;
										initEvent(info, EventType.Down, c);
										info.down.x = contacts[c].x;
										info.down.y = contacts[c].y;

										OnInputEvent(this, &info);
										break;
									}
								}
							}
						}
					}
/+
					float wheel = MFInput_Read(MFMouseButton.Wheel, device, deviceID);
					if(wheel)
					{
						// we'll simulate a pinch event on the mouses hover contact
						EventInfo info;
						initEvent(&info, EventType.Pinch, deviceID);
						info.pinch.centerX = contacts[a].x;
						info.pinch.centerY = contacts[a].y;
						info.pinch.deltaScale = wheel < 0.f ? 0.5f : 2.f;
						info.pinch.contact2 = -1;

						OnInputEvent(this, info);
					}
+/
				}
			}

			if(device == MFInputDevice.TouchPanel)
			{
				MFTouchPanelState* pState = MFInput_GetContactInfo(deviceID);

				foreach(b; 0..MaxContacts)
				{
					if(b < pState.numContacts && touchContacts[b] == -1 && pState.contacts[b].phase < 3)
					{
						for(int c=0; c<MaxContacts; ++c)
						{
							if(!bCurrentContacts[c])
							{
								bCurrentContacts[c] = true;
								touchContacts[b] = c;

								// create the hover contact
								MFVector pos = correctPosition(pState.contacts[b].x, pState.contacts[b].y);
								contacts[c].init(&sources[a], b, pos.x, pos.y);
								contacts[c].bState = true;

//								pNewContactCallback(c);

								// send the down event
								EventInfo info;
								initEvent(info, EventType.Down, b);
								info.down.x = contacts[c].x;
								info.down.y = contacts[c].y;

								OnInputEvent(this, &info);
								break;
							}
						}
					}
					else if(touchContacts[b] != -1 && (b >= pState.numContacts || pState.contacts[b].phase >= 3))
					{
						int c = touchContacts[b];

						if(!contacts[c].bDrag)
						{
							// event classifies as a tap
							EventInfo info;
							initEvent(info, EventType.Tap, contacts[c].buttonID);
							info.tap.x = contacts[c].x;
							info.tap.y = contacts[c].y;
							info.tap.holdLength = contacts[c].downTime;

							OnInputEvent(this, &info);
						}

						// send the up event
						EventInfo info;
						initEvent(info, EventType.Up, contacts[c].buttonID);
						info.up.x = contacts[c].x;
						info.up.y = contacts[c].y;
						info.up.downX = contacts[c].downX;
						info.up.downY = contacts[c].downY;
						info.up.holdLength = contacts[c].downTime;

						OnInputEvent(this, &info);

						bCurrentContacts[c] = false;
						touchContacts[b] = -1;
					}
				}
			}

			if(MFDisplay_HasFocus())
			{
				if(device == MFInputDevice.Keyboard)
				{
					foreach(int b; 0..MFKey.Max)
					{
						if(MFInput_WasPressed(b, device, deviceID))
						{
							EventInfo info;
							initButtonEvent(info, EventType.ButtonDown, b, a);
							OnInputEvent(this, &info);

							// button trigger supports repeats... (not yet supported)
//							info.ev = IE_ButtonTriggered;
//							OnInputEvent(*this, info);
						}
						else if(MFInput_WasReleased(b, device, deviceID))
						{
							EventInfo info;
							initButtonEvent(info, EventType.ButtonUp, b, a);
							OnInputEvent(this, &info);
						}
					}
				}
				else if(device == MFInputDevice.Gamepad)
				{
					foreach(int b; 0..MFGamepadButton.Max)
					{
						if(b >= MFGamepadButton.Axis_LX && b <= MFGamepadButton.Axis_RY)
						{
							// handle axiis discreetly
							float pX, pY;
							float x = MFInput_Read(MFGamepadButton.Axis_LX, device, deviceID, &pX);
							float y = MFInput_Read(MFGamepadButton.Axis_LY, device, deviceID, &pY);
							if(x != pX || y != pY)
							{
								EventInfo info;
								initAxisEvent(info, x, y, 0, a);
								OnInputEvent(this, &info);
							}

							x = MFInput_Read(MFGamepadButton.Axis_RX, device, deviceID, &pX);
							y = MFInput_Read(MFGamepadButton.Axis_RY, device, deviceID, &pY);
							if(x != pX || y != pY)
							{
								EventInfo info;
								initAxisEvent(info, x, y, 1, a);
								OnInputEvent(this, &info);
							}
						}
						else if(MFInput_WasPressed(b, device, deviceID))
						{
							EventInfo info;
							initButtonEvent(info, EventType.ButtonDown, b, a);
							OnInputEvent(this, &info);

							// button trigger supports repeats... (not yet supported)
//							info.ev = IE_ButtonTriggered;
//							OnInputEvent(*this, info);
						}
						else if(MFInput_WasReleased(b, device, deviceID))
						{
							EventInfo info;
							initButtonEvent(info, EventType.ButtonUp, b, a);
							OnInputEvent(this, &info);
						}
					}
				}
			}
		}

		// track moved contacts
		struct Moved
		{
			int contact;
			float x, y;
		}
		Moved[16] moved;
		int numMoved = 0;

		foreach(a; 0..MaxContacts)
		{
			if(!bCurrentContacts[a])
				continue;

			InputSource* pContactSource = contacts[a].pSource;
			MFInputDevice device = pContactSource.device;
			int deviceID = pContactSource.deviceID;

			if(device != MFInputDevice.TouchPanel)
			{
				if(!MFInput_IsReady(device, deviceID))
				{
					bCurrentContacts[a] = false;

					if(device == MFInputDevice.Mouse)
						mouseContacts[deviceID] = -1;
					else if(device == MFInputDevice.TouchPanel)
						touchContacts[contacts[a].buttonID] = -1;
				}

				if(device == MFInputDevice.Mouse)
				{
					MFVector pos = correctPosition(MFInput_Read(MFMouseButton.XPos, device, deviceID), MFInput_Read(MFMouseButton.YPos, device, deviceID));

					if(pos.x != contacts[a].x || pos.y != contacts[a].y)
					{
						EventInfo info;
						initEvent(info, EventType.Hover, a);
						info.hover.x = pos.x;
						info.hover.y = pos.y;
						info.hover.deltaX = pos.x - contacts[a].x;
						info.hover.deltaY = pos.y - contacts[a].y;

						OnInputEvent(this, &info);

						if(!contacts[a].bDrag)
						{
							float distX = pos.x - contacts[a].downX;
							float distY = pos.y - contacts[a].downY;
							if(sqrt(distX*distX + distY*distY) >= dragThreshold)
							{
								contacts[a].bDrag = true;

								// the first drag needs to compensate for the drag threshold
								info.hover.deltaX = pos.x - contacts[a].downX;
								info.hover.deltaY = pos.y - contacts[a].downY;
							}
						}

						if(contacts[a].bDrag && contacts[a].bState)
						{
							// send the drag event
							info.ev = EventType.Drag;
							info.drag.startX = contacts[a].downX;
							info.drag.startY = contacts[a].downY;

							OnInputEvent(this, &info);
						}

						contacts[a].x = pos.x;
						contacts[a].y = pos.y;
					}
				}

				if(contacts[a].bState)
				{
					if(!MFInput_Read(contacts[a].buttonID, device, deviceID))
					{
						// send the up event
						EventInfo info;
						initEvent(info, EventType.Up, a);
						info.up.x = contacts[a].x;
						info.up.y = contacts[a].y;
						info.up.downX = contacts[a].downX;
						info.up.downY = contacts[a].downY;
						info.up.holdLength = contacts[a].downTime;

						OnInputEvent(this, &info);

						if(!contacts[a].bDrag)
						{
							// event classifies as a tap
							initEvent(info, EventType.Tap, a);
							info.tap.x = contacts[a].x;
							info.tap.y = contacts[a].y;
							info.tap.holdLength = contacts[a].downTime;

							OnInputEvent(this, &info);
						}

						bCurrentContacts[a] = false;

						// if it was a mouse, release the button to we can sense it again
						if(device == MFInputDevice.Mouse)
							mouseButtonContacts[deviceID][contacts[a].buttonID - MFMouseButton.LeftButton] = -1;
					}
					else
					{
						contacts[a].downTime += MFTimeDelta();
					}
				}
			}
			else
			{
				MFVector pos = correctPosition(MFInput_Read(MFTouch_XPos(contacts[a].buttonID), MFInputDevice.TouchPanel), MFInput_Read(MFTouch_YPos(contacts[a].buttonID), MFInputDevice.TouchPanel));

				if(pos.x != contacts[a].x || pos.y != contacts[a].y)
				{
					EventInfo info;
					initEvent(info, EventType.Hover, a);
					info.hover.x = pos.x;
					info.hover.y = pos.y;
					info.hover.deltaX = pos.x - contacts[a].x;
					info.hover.deltaY = pos.y - contacts[a].y;

					OnInputEvent(this, &info);

					float distX = pos.x - contacts[a].downX;
					float distY = pos.y - contacts[a].downY;
					if(!contacts[a].bDrag && sqrt(distX*distX + distY*distY) >= dragThreshold)
					{
						contacts[a].bDrag = true;

						// the first drag needs to compensate for the drag threshold
						info.hover.deltaX = pos.x - contacts[a].downX;
						info.hover.deltaY = pos.y - contacts[a].downY;
					}

					if(contacts[a].bDrag && contacts[a].bState)
					{
						// send the drag event
						info.ev = EventType.Drag;
						info.drag.startX = contacts[a].downX;
						info.drag.startY = contacts[a].downY;

						OnInputEvent(this, &info);
					}

					// store the old pos for further processing
					moved[numMoved].x = contacts[a].x;
					moved[numMoved].y = contacts[a].y;
					moved[numMoved++].contact = a;

					contacts[a].x = pos.x;
					contacts[a].y = pos.y;
				}
			}
		}

		if(numMoved > 1)
		{
			// calculate rotation and zoom for each pair of contacts
			foreach(a; 0..numMoved)
			{
				foreach(b; a+1..numMoved)
				{
					// only compare contacts from the same input source
					if(contacts[moved[a].contact].pSource != contacts[moved[b].contact].pSource)
						continue;

					MFVector center;
					MFVector newa = MFVector(contacts[moved[a].contact].x, contacts[moved[a].contact].y);
					MFVector newDiff = MFVector(contacts[moved[b].contact].x, contacts[moved[b].contact].y) - newa;
					MFVector oldDiff = MFVector(moved[b].x - moved[a].x, moved[b].y - moved[a].y);
					center = madd!2(newDiff, MFVector(0.5f), newa);

					float oldLen = oldDiff.length!2();
					float newLen = newDiff.length!2();
					float scale = newLen / oldLen;

					EventInfo info;
					initEvent(info, EventType.Pinch, moved[a].contact);
					info.pinch.contact2 = moved[b].contact;
					info.pinch.centerX = center.x;
					info.pinch.centerY = center.y;
					info.pinch.deltaScale = scale;

					OnInputEvent(this, &info);

					oldDiff = mul!2(oldDiff, 1.0f/oldLen);
					newDiff = mul!2(newDiff, 1.0f/newLen);
					float angle = oldDiff.getAngle(newDiff);

					info.ev = EventType.Spin;
					info.spin.deltaAngle = angle;

					OnInputEvent(this, &info);
				}
			}
		}
	}


	InputEvent OnInputEvent;

	// should be properties...
	float _dragThreshold = 16;

protected:
	struct Contact
	{
		void init(InputSource* pSource, int buttonID = -1, float x = 0, float y = 0)
		{
			this.pSource = pSource;
			this.buttonID = buttonID;
			this.x = downX = x;
			this.y = downY = y;
			downTime = 0;
			bDrag = false;
			bState = false;
		}

		InputSource *pSource;
		int buttonID;

		float x, y;			// current position of contact
		float downX, downY;	// position each button was pressed down
		float downTime;		// length of down time for each button
		bool bState;		// bits represent the button pressed state
		bool bDrag;			// bits represent weather the interaction is a tap or a drag
	};

	enum MaxContacts = 16;

	InputSource[MaxSources] sources;
	int numDevices;

	Contact[MaxContacts] contacts;
	bool[MaxContacts] bCurrentContacts;
	int[MaxContacts] mouseContacts = -1;
	int[MFMouseButton.MaxButtons][MaxContacts] mouseButtonContacts = [-1];

	int[MaxContacts] touchContacts = -1;

	void scanForDevices()
	{
		// *** TODO: support hot-swapping devices... ***

		// scan for mouse devices
		int count = MFInput_GetNumPointers();
		for(int a=0; a < count && numDevices < MaxSources; ++a)
		{
			InputSource* source = &sources[numDevices];

			source.sourceID = numDevices;
			source.device = MFInputDevice.Mouse;
			source.deviceID = a;

			numDevices++;
		}

		count = MFInput_GetNumKeyboards();
		for(int a=0; a < count && numDevices < MaxSources; ++a)
		{
			InputSource* source = &sources[numDevices];

			source.sourceID = numDevices;
			source.device = MFInputDevice.Keyboard;
			source.deviceID = a;

			numDevices++;
		}

		count = MFInput_GetNumGamepads();
		for(int a=0; a < count && numDevices < MaxSources; ++a)
		{
			InputSource* source = &sources[numDevices];

			source.sourceID = numDevices;
			source.device = MFInputDevice.Gamepad;
			source.deviceID = a;

			numDevices++;
		}

		count = MFInput_GetNumTouchPanels();
		for(int a=0; a < count && numDevices < MaxSources; ++a)
		{
			InputSource* source = &sources[numDevices];

			source.sourceID = numDevices;
			source.device = MFInputDevice.TouchPanel;
			source.deviceID = a;

			numDevices++;
		}
	}

	MFVector correctPosition(float x, float y)
	{
		assert(MFDisplay_GetDisplayOrientation() == MFDisplayOrientation.Normal, "Support display rotation!");

		if(MFDisplay_GetDisplayOrientation() == MFDisplayOrientation.Normal)
		{
			return MFVector(x, y);
		}
		else
		{
//			MFMatrix inputMat;
//			GetInputMatrix(&inputMat);
//			return inputMat.TransformVectorH(MakeVector(x, y, 0.f, 1.f));
			return MFVector(x, y);
		}
	}

	void initEvent(ref EventInfo info, EventType ev, int contact)
	{
		info.ev = ev;
		info.contact = contact;
		info.pSource = contacts[contact].pSource;
		info.buttonID = contacts[contact].buttonID;

		// the mouse buttons are stored according to the MFInput enum values
		if(info.buttonID != -1 && info.pSource.device == MFInputDevice.Mouse)
			info.buttonID -= MFMouseButton.LeftButton;
	}

	void initButtonEvent(ref EventInfo info, EventType ev, int button, int source)
	{
		info.ev = ev;
		info.contact = -1;
		info.pSource = &sources[source];
		info.buttonID = button;
	}

	void initAxisEvent(ref EventInfo info, float x, float y, int stick, int source)
	{
		info.ev = EventType.Axis;
		info.contact = -1;
		info.pSource = &sources[source];
		info.buttonID = stick;
		info.axis.x = x;
		info.axis.y = y;
	}
}
