module db.ui.listadapter;

import db.ui.widget;
import db.tools.event;

import std.range;

class ListAdapter
{
	alias ListEvent = Event!(int, ListAdapter);

	abstract size_t length() const;

	abstract Widget getItemView(int item);
	abstract void updateItemView(int item, Widget layout);

	ListEvent OnInsertItem;
	ListEvent OnRemoveItem;
	ListEvent OnTouchItem;
}

class RangeAdapter(T) : ListAdapter if (isRandomAccessRange!T)
{
	alias ET = ElementType!T;

	alias range this;

	this()
	{
//		_range.OnInsert ~= &onInsert;
//		_range.OnRemove ~= &onRemove;
//		_range.OnChange ~= &onTouch;
	}

	this(ref T range)
	{
		_range = range;
		this();
	}

	~this()
	{
//		_range.OnInsert.unsubscribe(&onInsert);
//		_range.OnRemove.unsubscribe(&onRemove);
//		_range.OnChange.unsubscribe(&onTouch);
	}

	final @property ref inout(T) range() inout { return _range; }

	@property override size_t length() const { return _range.length; }

	abstract Widget getItemView(int index, ref T item);
	abstract void updateItemView(int index, ref T item, Widget layout);

protected:
	T _range;

	Widget getItemView(int item) { return getItemView(item, _range[item]); }
	void updateItemView(int item, Widget layout) { updateItemView(item, _range[item], layout); }

//	void onInsert(ref ET, int item, ref T) { OnInsertItem(item, this); }
//	void onRemove(ref ET, int item, ref T) { OnRemoveItem(item, this); }
//	void onTouch(ref ET, int item, ref T)  { OnTouchItem(item, this); }
}
