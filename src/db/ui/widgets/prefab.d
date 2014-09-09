module db.ui.widgets.prefab;

import db.ui.widgets.frame;
import db.ui.layoutdescriptor;

import std.string;

class Prefab : Frame
{
	override @property string typeName() const pure nothrow { return Unqual!(typeof(this)).stringof; }

	final @property string prefab() const pure nothrow { return _prefab; }
	final @property void prefab(string prefab)
	{
		loadPrefab(prefab);
	}

	override void setProperty(const(char)[] property, const(char)[] value)
	{
		if(!icmp(property, "prefab"))
			loadPrefab(value);
		else
			super.setProperty(property, value);
	}

	override string getProperty(const(char)[] property)
	{
		if(!icmp(property, "prefab"))
			return prefab;
		return super.getProperty(property);
	}

	final void loadPrefab(const(char)[] prefab)
	{
		clearChildren();

		_prefab = prefab.idup;

		if(prefab.length >= 4 && !icmp(prefab[$-4..$], ".xml"))
		{
			LayoutDescriptor desc = new LayoutDescriptor(prefab);
			addChild(desc.spawn());
		}
		else
		{
			assert(false, "Unknown prefab format!");
		}
	}

protected:
	string _prefab;
}
