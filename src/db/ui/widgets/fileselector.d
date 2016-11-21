module db.ui.widgets.fileselector;

import db.ui.inputmanager : InputSource;
import db.ui.ui;
import db.ui.widget;
import db.ui.widgets.linearlayout;
import db.ui.widgets.label;
import db.ui.widgets.listbox;
import db.ui.widgets.textbox;
import db.tools.event;

import fuji.fuji;
import fuji.vector;
import fuji.filesystem;
import std.range;
import std.traits : Unqual;

class FileSelector : LinearLayout
{
	this()
	{
		super();

		bgColour = MFVector.black;
		size = MFVector(600, 400);
		padding = MFVector(10, 10);

		_titleWidget = new Label;
		_titleWidget.textColour = MFVector.red;
		_titleWidget.visibility = Visibility.Gone;

		_listWidget = new Listbox;
		_listWidget.layoutJustification = Justification.Fill;
		_listWidget.OnClick ~= &onListSelect;

		_filterWidget = new Textbox;
		_filterWidget.visibility = Visibility.Gone;
		_filterWidget.OnChanged ~= &onFilterChange;

		addChild(_titleWidget);
		addChild(_listWidget);
		addChild(_filterWidget);
	}

	override @property string typeName() const pure nothrow { return Unqual!(typeof(this)).stringof; }

	@property const(char)[] filter() const { return _filterWidget.text; }
	@property void filter(string filter)
	{
		if (title)
		{
			_filterWidget.visibility = Visibility.Visible;
			_filterWidget.text = filter;
		}
		else
			_filterWidget.visibility = Visibility.Gone;
	}

	@property string title() const { return _titleWidget.text; }
	@property void title(string title)
	{
		if (title)
		{
			_titleWidget.visibility = Visibility.Visible;
			_titleWidget.text = title;
		}
		else
			_titleWidget.visibility = Visibility.Gone;
	}

	@property string root() const { return root; }
	@property void root(string root)
	{
		if (root.back != ':' && root.back != '/')
			root ~= '/';
		_root = root;
		_dir = root;

		updateList();
	}

	@property string path() const { return path; }

	Event!(DirEntry, Widget) OnSelectFile;

protected:
	string _root;
	string _dir;
	string _path;
	const(char)[][] _filters;

	DirEntry[] dirListing;

	Label _titleWidget;
	Listbox _listWidget;
	Textbox _filterWidget;

	void updateList()
	{
		import std.string : lastIndexOf;
		import fuji.string : patternMatch;
		import std.algorithm : max;

		dirListing = null;

		if (!_dir)
			return;

		if (_dir[] != _root[])
		{
			string parent = _dir[0..$-1];
			auto i = max(parent.lastIndexOf('/'), parent.lastIndexOf(':'));
			parent = parent[0..i+1];
			dirListing ~= DirEntry();
			dirListing[0].filepath = parent;
			dirListing[0].filename = "..";
			dirListing[0].attributes = MFFileAttributes.Directory;
		}

		foreach (entry; dirEntries(_dir, SpanMode.shallow))
		{
			if (!_filters || entry.isDir || entry.isSymlink)
				dirListing ~= entry;
			else
			{
				foreach (filter; _filters)
				{
					if (patternMatch(filter, entry.filename))
					{
						dirListing ~= entry;
						break;
					}
				}
			}
		}

		_listWidget.list = new DirListing(dirListing);
	}

	void onListSelect(int i, Widget w)
	{
		--i;
		if (dirListing[i].isDir || dirListing[i].isSymlink)
		{
			if (dirListing[i].filename[] == "..")
				_dir = dirListing[i].filepath;
			else
				_dir ~= dirListing[i].filename ~ '/';
			updateList();
		}
		else
			OnSelectFile(dirListing[i], this);
	}

	void onFilterChange(Widget, const(char)[] value, const(InputSource)*)
	{
		import std.algorithm : splitter, map;
		import std.string : strip;
		_filters = value.splitter(';').map!(e => e.strip).array;
		updateList();
	}
}

private:

import db.ui.listadapter;

class DirListing : RangeAdapter!(DirEntry[])
{
	this(DirEntry[] entries)
	{
		super(entries);
	}

	override Widget getItemView(int index, ref DirEntry item)
	{
		Label l = new Label();
		l.textHeight = 20;
		l.text = item.filename;
		l.textColour = (item.isDir || item.isSymlink) ? MFVector.yellow : MFVector.white;
		return l;
	}
	override void updateItemView(int index, ref DirEntry item, Widget layout)
	{
		Label l = cast(Label)layout;
		l.text = item.filename;
	}
}
