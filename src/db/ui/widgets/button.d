module db.ui.widgets.button;

import db.ui.widget;
import db.ui.widgets.label;
import db.ui.inputmanager;
import db.tools.enumkvp;
import db.tools.event;

import fuji.font;
import fuji.types;
import fuji.vector;

import std.string;
import std.traits : Unqual;

class Button : Label
{
	enum ButtonFlags
	{
		TriggerOnDown = 0x1,
		StateButton = 0x2
	}

	this()
	{
		bClickable = true;
		bHoverable = true;

		_textJustification = MFFontJustify.Center;

		OnDown ~= &onButtonDown;
		OnUp ~= &onButtonUp;
		OnHover ~= &onHover;
	}

	~this()
	{
		OnDown.unsubscribe(&onButtonDown);
		OnUp.unsubscribe(&onButtonUp);
		OnHover.unsubscribe(&onHover);
	}

	override @property string typeName() const pure nothrow { return Unqual!(typeof(this)).stringof; }

	final @property bool pressed() const pure nothrow { return bPressed; }

	final @property bool state() const pure nothrow { return bState; }
	final @property void state(bool bState) pure nothrow { this.bState = bState; }

	final @property void stylePressed(const(char)[] style) pure nothrow { _stylePressed = style.idup; }
	final @property void styleState(const(char)[] style) pure nothrow { _styleOnState = style.idup; }

	final @property uint buttonFlags() const pure nothrow { return _buttonFlags; }
	final @property void buttonFlags(uint flags) pure nothrow { _buttonFlags = flags; }

	override void setProperty(const(char)[] property, const(char)[] value)
	{
		switch(property.toLower)
		{
			case "style_pressed":
				stylePressed = value; break;
			case "style_selected":
				styleState = value; break;
			case "button_state":
				state = getBoolFromString(value); break;
			case "button_flags":
				buttonFlags = getBitfieldValue!ButtonFlags(value); break;
			case "onclick":
				bindEvent!OnClick(value); break;
			default:
				super.setProperty(property, value);
		}
	}

	override string getProperty(const(char)[] property)
	{
		if(!icmp(property, "button_flags"))
			return getBitfieldFromValue!ButtonFlags(buttonFlags);
		return super.getProperty(property);
	}

	// state change events
	Event!(Widget, const(InputSource)*) OnClick;

protected:
	string _stylePressed;
	string _styleOnState;

	uint _buttonFlags;

	bool bDown;
	bool bPressed;
	bool bState;

	final void setPressed(bool bPressed)
	{
		if(bPressed != this.bPressed)
		{
			this.bPressed = bPressed;
			updateStyle();
		}
	}

	final void setButtonState(bool bState)
	{
		if(bState != this.bState)
		{
			this.bState = bState;
			updateStyle();
		}
	}

	override void updateStyle()
	{
		if(!bEnabled && _styleDisabled.length > 0)
			applyStyle(_styleDisabled);
		else if(bPressed && _stylePressed.length > 0)
			applyStyle(_stylePressed);
		else if(bState && _styleOnState.length > 0)
			applyStyle(_styleOnState);
		else if(_style.length > 0)
			applyStyle(_style);
	}

	final void onButtonDown(Widget widget, const(InputSource)* pSource)
	{
		if(!bEnabled)
			return;

		if(_buttonFlags & ButtonFlags.TriggerOnDown)
		{
			if(buttonFlags & ButtonFlags.StateButton)
				setButtonState(!bState);

			if(OnClick)
				OnClick(this, pSource);
		}
		else
		{
			bDown = true;
			setPressed(true);

			ui.setFocus(pSource, this);
		}
	}

	final void onButtonUp(Widget widget, const(InputSource)* pSource)
	{
		if(!bEnabled)
			return;

		bDown = false;

		ui.setFocus(pSource, null);

		if(bPressed)
		{
			setPressed(false);

			if(_buttonFlags & ButtonFlags.StateButton)
				setButtonState(!bState);

			if(OnClick)
				OnClick(this, pSource);
		}
	}

	final void onHover(Widget widget, const(InputSource)* pSource, MFVector pos, MFVector delta)
	{
		if(!bEnabled)
			return;

		if(bDown)
		{
			MFRect rect = MFRect(0, 0, size.x, size.y);
			if(MFTypes_PointInRect(pos.x, pos.y, rect))
				setPressed(true);
			else
				setPressed(false);
		}
	}
}
