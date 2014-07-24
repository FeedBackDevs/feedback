module db.ui.widgets.layout;

import db.ui.widget;
import db.ui.widgetevent;

import fuji.dbg;
import fuji.vector;

import std.string;

class Layout : Widget
{
	enum FitFlags
	{
		FitContentVertical = 1,
		FitContentHorizontal = 2,
		FitContent = 3
	}

	this() pure nothrow
	{
		OnResize ~= &onLayoutDirty;
	}

	~this() pure nothrow
	{
		OnResize.unsubscribe(&onLayoutDirty);
	}

	final size_t addChild(Widget child)
	{
		size_t id = _children.length;
		_children ~= child;

		child.parent = this;
		child.OnLayoutChanged ~= &onLayoutDirty;

		arrangeChildren();

		return id;
	}

	final void removeChild(Widget child)
	{
		foreach(i, c; _children)
		{
			if(child == c)
			{
				removeChild(i);
				return;
			}
		}

		MFDebug_Assert("Child does not exist!");
	}

	final void removeChild(size_t index)
	{
		_children[index].OnLayoutChanged.unsubscribe(&onLayoutDirty);

		_children = _children[0..index] ~ _children[index+1..$];

		arrangeChildren();
	}

	final void clearChildren()
	{
		foreach(child; _children)
			child.OnLayoutChanged.unsubscribe(&onLayoutDirty);

		_children = null;

		arrangeChildren();
	}

	override @property Widget[] children() pure nothrow
	{
		return _children;
	}

	override void setProperty(const(char)[] property, const(char)[] value)
	{
		switch(property.toLower)
		{
			case "padding":
				padding = getVectorFromString(value); break;
			case "layout_flags":
				fitFlags = getBitfieldValue!FitFlags(value); break;
			default:
				super.setProperty(property, value);
		}
	}

	override string getProperty(const(char)[] property)
	{
		if(!property.icmp("layout_flags"))
			return getBitfieldFromValue!FitFlags(_fitFlags);
		return super.getProperty(property);
	}

	final @property ref const(MFVector) padding() const pure nothrow { return _padding; }
	final @property void padding(const(MFVector) padding)
	{
		if(_padding != padding)
		{
			_padding = padding;

			// potentially
			MFVector newSize = max(_size, MFVector(padding.x + padding.z, padding.y + padding.w));
			if(newSize != _size)
				resize(newSize);
			else
				arrangeChildren();
		}
	}

	final @property uint fitFlags() const pure nothrow { return _fitFlags; }
	final @property void fitFlags(uint fitFlags)
	{
		if(_fitFlags != fitFlags)
		{
			_fitFlags = fitFlags;
			arrangeChildren();
		}
	}

protected:
	MFVector _padding;
	uint _fitFlags;

	Widget[] _children;

	abstract void arrangeChildren();

	final void onLayoutDirty(Widget child, const(WidgetEventInfo)* ev)
	{
		// we may need to rearrange the children
		arrangeChildren();
	}

	final void resizeChild(Widget child, const(MFVector) newSize)
	{
		// TODO: remove me? seems pointless
		child.resize(newSize);
	}
}
