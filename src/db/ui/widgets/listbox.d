module db.ui.widgets.listbox;

import db.ui.widget;
import db.ui.widgets.frame;
import db.ui.widgets.layout;
import db.ui.listadapter;
import db.ui.inputmanager;
import db.tools.enumkvp;
import db.tools.event;

import fuji.fuji;
import fuji.vector;

import std.math : floor;
import std.string;
import std.traits : Unqual;
import std.typecons : tuple;

class Listbox : Layout
{
	enum Orientation
	{
		Horizontal,
		Vertical
	}

	enum Flags
	{
		HoverSelect = 1
	}

	enum WrapMode
	{
		None,		// no wrapping
		Selection,	// wrap the selection cursor
		Contents	// repeat contents as a cycle
	}

	this()
	{
		dragable = true;
		clickable = true;

		padding = MFVector(2,2,2,2);
	}

	~this()
	{
		unbind();
	}

	override @property string typeName() const pure nothrow @nogc { return Unqual!(typeof(this)).stringof; }

	@property final inout(ListAdapter) list() inout pure nothrow @nogc { return _list; }
	@property final void list(ListAdapter list) { bind(list); }

	@property final size_t numItems() const { return _list ? _list.length : 0; }

	@property final Orientation orientation() const pure nothrow @nogc { return _orientation; }
	@property final void orientation(Orientation orientation) pure nothrow @nogc { _orientation = orientation; }

	@property final uint flags() const pure nothrow @nogc { return _flags; }
	@property final void flags(uint flags) pure nothrow @nogc { _flags = flags; }

	@property final float maxSize() const pure nothrow @nogc
	{
		if (orientation == Orientation.Horizontal)
			return contentSize + padding.x + padding.z;
		else
			return contentSize + padding.y + padding.w;
	}

	@property final int selection() const pure nothrow @nogc { return _selection; }
	@property final void selection(int item)
	{
		if (item >= cast(int)children.length)
			item = -1;

		if (_selection != item)
		{
			if (selection > -1)
				children[_selection].setProperty("background_colour", "0,0,0,0");
			if (item > -1)
				children[item].setProperty("background_colour", "0,0,1,0.6");

			_selection = item;

			if (OnSelChanged)
				OnSelChanged(item, this);
		}
	}

	final inout(Widget) getItemView(size_t item) inout
	{
		return children[item].children[0];
	}

	final void bind(ListAdapter adapter)
	{
		unbind();

		if (!adapter)
			return;

		_list = adapter;

		// subscribe for list adapter events
		_list.OnInsertItem ~= &onInsert;
		_list.OnRemoveItem ~= &onRemove;
		_list.OnTouchItem ~= &onChange;

		// populate the children with each item
		foreach (int i; 0 .. cast(int)_list.length)
		{
			Widget item = _list.getItemView(i);
			addView(item);
		}
	}

	final void unbind()
	{
		if (_list)
		{
			// unsubscribe from adapter
			_list.OnInsertItem.unsubscribe(&onInsert);
			_list.OnRemoveItem.unsubscribe(&onRemove);
			_list.OnTouchItem.unsubscribe(&onChange);
			_list = null;
		}

		_selection = -1;
		scrollOffset = 0;

		clearChildren();
	}

	override void setProperty(const(char)[] property, const(char)[] value)
	{
		if (!icmp(property, "list"))
		{
			import db.lua;
			try
			{
				LuaObject obj = getLuaObject(value);
				list = obj.to!LuaArrayAdaptor;
			}
			catch (Exception e)
				MFDebug_Warn(2, "Couldn't bind array '"~value~"'. "~e.msg);
		}
		else if (!icmp(property, "orientation"))
			orientation = getEnumValue!Orientation(value);
		else if (!icmp(property, "hoverSelect"))
			flags = (flags & ~Flags.HoverSelect) | (getBoolFromString(value) ? Flags.HoverSelect : 0);
		else if (!icmp(property, "onSelChanged"))
			bindEvent!(OnSelChanged, (int i, Widget w) => tuple!(int, Widget)(i + 1, w))(value, "local item, widget = ...");
		else if (!icmp(property, "onClick"))
			bindEvent!(OnClick, (int i, Widget w) => tuple!(int, Widget)(i + 1, w))(value, "local item, widget = ...");
		else
			super.setProperty(property, value);
	}

	override string getProperty(const(char)[] property)
	{
		if (!icmp(property, "orientation"))
			return getEnumFromValue(orientation);
		return super.getProperty(property);
	}


	Event!(int, Widget) OnSelChanged;
	Event!(int, Widget) OnClick;

protected:
	Orientation _orientation = Orientation.Vertical;

	ListAdapter _list;
	Widget oldFocus;

	int _selection = -1;

	float contentSize = 0;
	float scrollOffset = 0, prevScrollOffset = 0;
	float velocity = 0;

	uint _flags;

	bool bDragging;

	final void addView(Widget view)
	{
		// it might be better to write a custom ListItem widget here, Frame might be a bit heavy for the purpose...
		Frame frame = ui.createWidget!Frame();
		frame.addChild(view);
		frame.clickable = true;
		frame.hoverable = true;

		// make child clickable
		frame.OnDown ~= &onItemDown;
		frame.OnTap ~= &onItemClick;
		frame.OnHoverOver ~= &onItemOver;
		frame.OnHoverOut ~= &onItemOut;

		addChild(frame);
	}

	override void update()
	{
		if (!bDragging)
		{
			if (velocity != 0)
			{
				// apply scroll velocity
				velocity *= 1.0f - MFTimeDelta()*10.0f;
				if (velocity < 0.01f)
					velocity = 0;

				scrollOffset += velocity * MFTimeDelta();
			}

			if (scrollOffset > 0.0f)
			{
				scrollOffset = MFMax(scrollOffset - MFMax(scrollOffset * 10.0f * MFTimeDelta(), 1.0f), 0.0f);
			}
			else
			{
				float listSize = orientation == Orientation.Horizontal ? size.x - (padding.x + padding.z) : size.y - (padding.y + padding.w);
				float overflow = MFMin(listSize - (contentSize + scrollOffset), -scrollOffset);
				if (overflow > 0.0f)
				{
					scrollOffset = MFMin(scrollOffset + MFMax(overflow * 10.0f * MFTimeDelta(), 1.0f), scrollOffset + overflow);
				}
			}
		}

		scrollOffset = scrollOffset.floor;
		if (scrollOffset != prevScrollOffset)
		{
			prevScrollOffset = scrollOffset;
			arrangeChildren();
		}
	}

	override bool inputEvent(InputManager manager, const(InputManager.EventInfo)* ev)
	{
		// try and handle the input event in some standard ways...
		switch (ev.ev)
		{
			case InputManager.EventType.Down:
			{
				// immediately stop the thing from scrolling
				velocity = 0;
				scrollOffset = scrollOffset.floor;

				// if the down stroke is outside the listbox, we have triggered a non-click
				MFRect rect = MFRect(0, 0, size.x, size.y);
				if (!MFTypes_PointInRect(ev.down.x, ev.down.y, rect))
				{
					if (OnClick)
						OnClick(-1, this);
				}
				break;
			}
			case InputManager.EventType.Up:
			{
				if (bDragging)
				{
					bDragging = false;
					ui.setFocus(ev.pSource, oldFocus);
				}
				break;
			}
			case InputManager.EventType.Drag:
			{
				// scroll the contents
				float delta = orientation == Orientation.Horizontal ? ev.drag.deltaX : ev.drag.deltaY;
				scrollOffset += delta;

				enum float smooth = 0.5;
				velocity = velocity*smooth + (delta / MFTimeDelta())*(1.0f-smooth);

				if (!bDragging)
				{
					bDragging = true;
					oldFocus = ui.setFocus(ev.pSource, this);
				}
				break;
			}
			default:
				break;
		}

		return super.inputEvent(manager, ev);
	}

	override void arrangeChildren()
	{
		// early out?
		if (children.length == 0)
			return;

		MFVector pPos = orientation == Orientation.Horizontal ? MFVector(padding.x + scrollOffset, padding.y) : MFVector(padding.x, padding.y + scrollOffset);
		MFVector pSize = MFVector(size.x - (padding.x + padding.z), size.y - (padding.y + padding.w));

		contentSize = 0;

		foreach (widget; children)
		{
			if (widget.visibility == Visibility.Gone)
				continue;

			MFVector cMargin = widget.layoutMargin;
			MFVector cSize = widget.size;

			MFVector tPos = pPos + MFVector(cMargin.x, cMargin.y);
			MFVector tSize = max(pSize - MFVector(cMargin.x + cMargin.z, cMargin.y + cMargin.w), MFVector.zero);

			if (orientation == Orientation.Horizontal)
			{
				float itemSize = cSize.x + cMargin.x + cMargin.z;
				contentSize += itemSize;
				pPos.x += itemSize;
				widget.position = tPos;
				widget.height = tSize.y;
			}
			else
			{
				float itemSize = cSize.y + cMargin.y + cMargin.w;
				contentSize += itemSize;
				pPos.y += itemSize;
				widget.position = tPos;
				widget.width = tSize.x;
			}
		}
	}


	final void onInsert(int position, ListAdapter adapter)
	{
		selection = -1;

		Widget view = adapter.getItemView(position);
		addView(view);
	}

	final void onRemove(int position, ListAdapter adapter)
	{
		selection = -1;

		removeChild(position);
	}

	final void onChange(int position, ListAdapter adapter)
	{
		adapter.updateItemView(position, getItemView(position));
	}


	final void onItemDown(Widget widget, const(InputSource)* pSource)
	{
		// a down stroke should immediately stop any innertial scrolling
		velocity = 0;
		scrollOffset = scrollOffset.floor;

		if (!(flags & Flags.HoverSelect))
			selection = cast(int)getChildIndex(widget);
	}

	final void onItemClick(Widget widget, const(InputSource)* pSource)
	{
		if (OnClick)
			OnClick(cast(int)getChildIndex(widget), this);
	}

	final void onItemOver(Widget widget, const(InputSource)* pSource)
	{
		if (flags & Flags.HoverSelect)
			selection = cast(int)getChildIndex(widget);
	}

	final void onItemOut(Widget widget, const(InputSource)* pSource)
	{
		if (flags & Flags.HoverSelect)
			selection = -1;
	}
}
