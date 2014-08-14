module db.ui.widgets.layout;

import db.ui.widget;
import db.ui.widgetevent;
import db.tools.enumkvp;

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
		size_t index = _children.length;
		_children ~= child;

		child.parent = this;
		child.OnLayoutChanged ~= &onLayoutDirty;

		arrangeChildren();

		return index;
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

		assert(false, "Child does not exist!");
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

	final int setDepth(Widget child, int depth) pure nothrow
	{
		depth = _children.length <= depth ? cast(int)_children.length - 1 : depth;
		depth = cast(int)_children.length - depth - 1;
		foreach(i, c; _children)
		{
			if(child is c)
			{
				if(depth < i)
					_children = _children[0..depth] ~ child ~ _children[depth..i] ~ _children[i+1..$];
				else if(depth > i)
					_children = _children[0..i] ~ _children[i+1..depth] ~ child ~ _children[depth..$];
				return depth;
			}
		}
		return -1;
	}

	final int getDepth(const(Widget) child) const pure nothrow
	{
		foreach(int i, c; _children)
		{
			if(c is child)
				return cast(int)_children.length - i - 1;
		}
		return -1;
	}

	final int raise(Widget child)
	{
		return setDepth(child, 0);
	}

	final int lower(Widget child)
	{
		return setDepth(child, cast(int)_children.length - 1);
	}

	final int stackUnder(Widget child, Widget under)
	{
		if(child is under)
			return getDepth(child);

		int other = -1;
		foreach(int i, c; _children)
		{
			if(c is child)
			{
				if(other == -1)
					other = i;
				else
				{
					_children = _children[0..other+1] ~ child ~ _children[other+1..i] ~ _children[i+1..$];
					return other + 1;
				}
			}
			else if(c is under)
			{
				if(other == -1)
					other = i;
				else
				{
					_children = _children[0..other] ~ _children[other+1..i+1] ~ child ~ _children[i+1..$];
					return i;
				}
			}
		}
		return -1;
	}

	final int stackAbove(Widget child, Widget above)
	{
		return stackUnder(above, child);
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
