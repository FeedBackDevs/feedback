module db.ui.widgets.label;

import db.ui.widget;
import db.tools.enumkvp;

import fuji.vector;
import fuji.matrix;
import fuji.font;
import fuji.string;

import std.string;
import std.conv;
import std.traits : Unqual;

import db.lua;

class Label : Widget
{
	this()
	{
		_font = Font.debugFont;
		_textHeight = _font.height;

		if(bAutoHeight)
			updateHeight(_textHeight);
	}

	override @property string typeName() const pure nothrow @nogc { return Unqual!(typeof(this)).stringof; }

	final @property string text() const pure nothrow @nogc { return _text; }
	final @property void text(const(char)[] text)
	{
		_text = text.idup;
		adjustSize();
	}

	final @property string fontName() const pure nothrow @nogc { return _fontName; }

	// TODO: fix inout in LuaD
	@noscript final @property inout(Font) font() inout pure nothrow @nogc { return _font; }
	final @property void font(Font font) @nogc
	{
		_font = font;
	}

	final @property ref const(MFVector) textColour() const pure nothrow @nogc { return _textColour; }
	final @property void textColour(const(MFVector) colour) pure nothrow @nogc { _textColour = colour; }

	final @property MFFontJustify textJustification() const pure nothrow @nogc { return _textJustification; }
	final @property void textJustification(MFFontJustify justification) pure nothrow @nogc { _textJustification = justification; }

	final @property float textHeight() const pure nothrow @nogc { return _textHeight; }
	final @property void textHeight(float height)
	{
		_textHeight = height;
		bAutoTextHeight = false;
		adjustSize();
	}

	final @property float shadowDepth() const pure nothrow @nogc { return _shadowDepth; }
	final @property void shadowDepth(float depth) pure nothrow @nogc { _shadowDepth = depth; }

	final void loadFont(const(char)[] font) nothrow @nogc
	{
		_font = Font(font);
	}

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
			case "text_shadowDepth":
				shadowDepth = to!float(value); break;
			case "font":
				_font = Font(value);
				if(bAutoTextHeight)
					textHeight = _font.height;
				adjustSize();
				break;
			case "text_align":
				textJustification = getEnumValue!MFFontJustify(value); break;
			default:
				super.setProperty(property, value);
		}
	}

	override string getProperty(const(char)[] property)
	{
		switch(property.toLower)
		{
			case "text":
				return text;
			case "font":
				if(_fontName)
					return _fontName;
//				return _font.name.idup;
				return null;
			case "text_align":
				return getEnumFromValue(textJustification);
			default:
				return super.getProperty(property);
		}
	}

protected:
	MFVector _textColour = MFVector.black;

	string _text;
	string _fontName;

	Font _font;
	MFFontJustify _textJustification = MFFontJustify.Top_Left;

	float _textHeight;
	float _shadowDepth;

	bool bAutoTextHeight = true;

	final void adjustSize()
	{
		if(bAutoWidth || bAutoHeight)
		{
			MFVector newSize = size;

			if(_text.length > 0)
			{
				auto t = Stringz!(256)(_text);

				// resize the widget accordingly
				float height;
				float width = MFFont_GetStringWidth(_font.handle, t, _textHeight, bAutoWidth ? 0 : _size.x, -1, &height);

				if(bAutoWidth)
					newSize.x = width;
				if(bAutoHeight)
					newSize.y = height;
			}
			else
			{
				if(bAutoWidth)
					newSize.x = 0;
				if(bAutoHeight)
					newSize.y = _textHeight;
			}

			resize(newSize);
		}
	}

	override void render()
	{
		super.render();

		if(_text.length > 0)
		{
			auto t = Stringz!(256)(_text);

			if(_shadowDepth > 0)
			{
				MFVector sd = MFVector(_shadowDepth, _shadowDepth);
				MFFont_DrawTextJustified(_font.handle, t.cstr, sd, _size.x, _size.y, _textJustification, _textHeight, MFVector.black, -1, transform);
			}
			MFVector tc = _textColour*_colour;
			MFFont_DrawTextJustified(_font.handle, t.cstr, MFVector.zero, _size.x, _size.y, _textJustification, _textHeight, tc, -1, transform);
		}
	}
}
