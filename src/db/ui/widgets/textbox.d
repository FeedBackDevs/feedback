module db.ui.widgets.textbox;

import db.ui.widget;
import db.ui.widgetevent;
import db.ui.stringentrylogic;
import db.ui.inputmanager;
import db.tools.enumkvp;

import fuji.fuji;
import fuji.input;
import fuji.font;
import fuji.types;
import fuji.vector;
import fuji.primitive;

import std.string;
import std.traits : Unqual;
import std.conv;
import std.utf: count;
import std.math: abs;

import luad.base;

class Textbox : Widget
{
	this()
	{
		stringLogic = new StringEntryLogic;
		stringLogic.setChangeCallback(&stringChangeCallback);

		_font = Font.debugFont;
		_textHeight = font.height;

		clickable = true;

		if(bAutoHeight)
			updateHeight(_textHeight + _padding*2);
	}

	@property final const(char)[] text() const pure nothrow @nogc { return stringLogic.text; }
	@property final void text(const(char)[] text) { stringLogic.text = text; }

	@property final const(char)[] renderText() const pure nothrow @nogc { return stringLogic.renderText; }

	@property final bool empty() const pure nothrow @nogc { return !stringLogic.text.length; }

	// TODO: Fuji stuff doesn't work with Lua...
	@noscript @property final inout(Font) font() inout pure nothrow @nogc { return _font; }
	@noscript @property final void font(Font font) nothrow @nogc { _font = font; }

	@property final ref const(MFVector) textColour() const pure nothrow @nogc { return _textColour; }
	@property final void textColour(const(MFVector) colour) pure nothrow @nogc { _textColour = colour; }
	@property final ref const(MFVector) highlightColour() const pure nothrow @nogc { return _highlightColour; }
	@property final void highlightColour(const(MFVector) colour) pure nothrow @nogc { _highlightColour = colour; }
	@property final ref const(MFVector) inactiveHighlightColour() const pure nothrow @nogc { return _inactiveHighlightColour; }
	@property final void inactiveHighlightColour(const(MFVector) colour) pure nothrow @nogc { _inactiveHighlightColour = colour; }

	@property final float textHeight() const pure nothrow @nogc { return _textHeight; }
	@property final void textHeight(float height)
	{
		_textHeight = height;
		bAutoTextHeight = false;

		if(bAutoHeight)
			updateHeight(_textHeight + _padding*2);
	}

	@property final int cursorPos() const pure nothrow @nogc { return stringLogic.cursorPos; }
	final void getSelection(out int start, out int end) const pure nothrow @nogc { stringLogic.getSelection(start, end); }

	@property final bool hasFocus() const nothrow @nogc
	{
		return pFocusKeyboard && getUI().getFocus(pFocusKeyboard) is this;
	}

	@property final StringEntryLogic.StringType type() const pure nothrow @nogc { return stringLogic.type; }
	@property final void type(StringEntryLogic.StringType type) pure nothrow @nogc { stringLogic.type = type; }

	override void setProperty(const(char)[] property, const(char)[] value)
	{
		switch(property.toLower)
		{
			case "text":
				text = value; break;
			case "text_colour":
				textColour = getColourFromString(value); break;
			case "text_height":
				textHeight = to!float(value); break;
			case "font":
			{
				_font.create(value);
				if(bAutoTextHeight)
					_textHeight = _font.height;
				if(bAutoHeight)
					updateHeight(_textHeight + _padding*2);
				break;
			}
			case "highlight_colour":
				highlightColour = getColourFromString(value); break;
			case "inactive_highlight_colour":
				inactiveHighlightColour = getColourFromString(value); break;
			case "type":
				type = getEnumValue!(StringEntryLogic.StringType)(value); break;
			case "onChanged":
				bindEvent!WidgetEvent(OnChanged, value); break;
			default:
				super.setProperty(property, value);
		}
	}

	override string getProperty(const(char)[] property)
	{
		if(!icmp(property, "text"))
			return text.idup;
		else if(!icmp(property, "font"))
			return _font.name.idup;
		return super.getProperty(property);
	}


	WidgetEvent OnChanged;

protected:
	StringEntryLogic stringLogic;

	MFVector _textColour = MFVector.white;
	MFVector _highlightColour = MFVector(0, 0, 1, 0.6f);
	MFVector _inactiveHighlightColour = MFVector(1, 1, 1, 0.4f);
	Font _font;

	float _textHeight;
	float _padding = 2;

	InputSource *pFocusKeyboard;

	bool bAutoTextHeight = true;

	__gshared float blinkTime;


	override void update()
	{
		super.update();

		if(hasFocus)
			stringLogic.update();
	}

	override bool inputEvent(InputManager manager, const(InputManager.EventInfo)* ev)
	{
		// try and handle the input event in some standard ways...
		switch(ev.ev)
		{
			case InputManager.EventType.Down:
			{
				// set the cursor pos
				bool bUpdateSelection = MFInput_Read(MFKey.LShift, MFInputDevice.Keyboard) || MFInput_Read(MFKey.RShift, MFInputDevice.Keyboard);
				updateCursorPos(ev.down.x, bUpdateSelection);

				// allow drag selection
				getUI().setFocus(ev.pSource, this);

				// also claim keyboard focus...
				pFocusKeyboard = manager.findSource(MFInputDevice.Keyboard, ev.pSource.deviceID);
				if(pFocusKeyboard)
					getUI().setFocus(pFocusKeyboard, this);

				blinkTime = 0.4f;
				break;
			}
			case InputManager.EventType.Up:
			{
				getUI().setFocus(ev.pSource, null);
			}
			case InputManager.EventType.Drag:
			{
				// drag text selection
				updateCursorPos(ev.drag.x, true);
				blinkTime = 0.4f;
				break;
			}
			default:
				break;
		}

		return super.inputEvent(manager, ev);
	}

	final void stringChangeCallback(const(char)[] text)
	{
		blinkTime = 0.4f;

		if(!OnChanged.empty)
		{
			WidgetTextEvent ev = WidgetTextEvent(this, text);
			OnChanged(this, &ev.base);
		}
	}

	final void updateCursorPos(float x, bool bUpdateSelection)
	{
		const(char)[] _text = stringLogic.renderText;

		float magnitude = 10000000.0f, downPos = x - 2;
		size_t offset = 0, len = _text.count;
		foreach(a; 0 .. len+1)
		{
			float _x = _font.getStringWidth(_text, _textHeight, 100000, cast(int)a);
			float m = abs(_x - downPos);
			if(m < magnitude)
			{
				magnitude = m;
				offset = a;
			}
			else
				break;
		}

		stringLogic.setCursorPos(offset, bUpdateSelection);
	}

	override final void render()
	{
		super.render();

		const(char)[] _text = renderText;

		int selectionStart, selectionEnd;
		getSelection(selectionStart, selectionEnd);

		bool bDrawSelection = selectionStart != selectionEnd;
		bool bEnabled = enabled;
		bool bHasFocus = hasFocus;

		if(bDrawSelection)
		{
			// draw selection (if selected)
			int selMin = MFMin(selectionStart, selectionEnd);
			int selMax = MFMax(selectionStart, selectionEnd);

			float selMinX = _font.getStringWidth(_text, _textHeight, 10000, selMin);
			float selMaxX = _font.getStringWidth(_text, _textHeight, 10000, selMax);

			MFVector selectionColour = bHasFocus ? _highlightColour : _inactiveHighlightColour;
			MFPrimitive_DrawUntexturedQuad(_padding+selMinX, _padding, selMaxX-selMinX, _textHeight, selectionColour, transform);
		}

		if(text.length)
		{
			// draw text
			_font.draw(_text, _padding, _padding, _textHeight, bEnabled ? _textColour : MFVector.grey, transform);
		}

		if(bHasFocus)
		{
			// blink cursor
			blinkTime -= MFTimeDelta();
			if(blinkTime < -0.4f) blinkTime += 0.8f;
			bool bCursor = blinkTime > 0.0f;

			// draw cursor
			if(bCursor)
			{
				float cursorX =  _font.getStringWidth(_text, _textHeight, 10000, cursorPos);

				// render cursor
				MFPrimitive_DrawUntexturedQuad(_padding+cursorX, _padding+1.0f, 2, _textHeight-2.0f, MFVector.white, transform);
			}
		}
	}
}
