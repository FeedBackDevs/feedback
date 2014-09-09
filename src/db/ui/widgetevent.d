module db.ui.widgetevent;

public import db.tools.event;

import db.ui.inputmanager;
import db.ui.widget;

import fuji.vector;


struct WidgetEventInfo
{
	this(Widget sender) pure nothrow
	{
		this.sender = sender;
	}

	Widget sender;
	void *pUserData;
}

alias WidgetEvent = Event!(Widget, WidgetEventInfo*);


// events...
struct WidgetGeneralEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender) pure nothrow
	{
		base = WidgetEventInfo(sender);
	}
}

struct WidgetEnabledEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender, bool bEnabled) pure nothrow
	{
		base = WidgetEventInfo(sender);
		this.bEnabled = bEnabled;
	}

	bool bEnabled;
}

struct WidgetVisibilityEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender, int visible) pure nothrow
	{
		base = WidgetEventInfo(sender);
		this.visible = visible;
	}

	int visible;
}

struct WidgetFocusEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender, bool bGainedFocus) pure nothrow
	{
		base = WidgetEventInfo(sender);
		this.bGainedFocus = bGainedFocus;
	}

	bool bGainedFocus;

	Widget gainedFocus;
	Widget lostFocus;
}

struct WidgetMoveEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender) pure nothrow
	{
		base = WidgetEventInfo(sender);
	}

	MFVector newPos;
	MFVector oldPos;
}

struct WidgetResizeEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender) pure nothrow
	{
		base = WidgetEventInfo(sender);
	}

	MFVector newSize;
	MFVector oldSize;
}

struct WidgetInputEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender, const(InputSource)* pSource) pure nothrow
	{
		base = WidgetEventInfo(sender);
		this.pSource = pSource;
	}

	const(InputSource)* pSource;
}

struct WidgetInputActionEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender, const(InputSource)* pSource) pure nothrow
	{
		base = WidgetEventInfo(sender);
		this.pSource = pSource;
	}

	const(InputSource)* pSource;
	MFVector pos;
	MFVector delta;
}

struct WidgetInputCharacterEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender, const(InputSource)* pSource, dchar unicode) pure nothrow
	{
		base = WidgetEventInfo(sender);
		this.pSource = pSource;
		this.unicode = unicode;
	}

	const(InputSource)* pSource;
	dchar unicode;
}

struct WidgetTextEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender, const(char)[] text) pure nothrow
	{
		base = WidgetEventInfo(sender);
		this.text = text;
	}

	const(InputSource)* pSource;
	const(char)[] text;
}

struct WidgetSelectEvent
{
	alias base this;
	WidgetEventInfo base;

	this(Widget sender, int selection) pure nothrow
	{
		base = WidgetEventInfo(sender);
		this.selection = selection;
	}

	int selection;
}
