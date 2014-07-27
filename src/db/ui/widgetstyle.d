module db.ui.widgetstyle;

import db.ui.widget;

import fuji.dbg;
import fuji.heap;
import fuji.filesystem;

import std.xml;
import std.file;

struct WidgetStyle
{
	static bool loadStylesFromXML(const(char)[] filename)
	{
		char[] file = cast(char[])MFFileSystem_Load(filename);
		if(!file)
			return false;

		try
		{
			// parse xml
			auto xml = new DocumentParser(file.idup);

			assert(xml.tag.name == "Resources", "Root element should be <Resources>");

			xml.onStartTag["Style"] = (ElementParser xml)
			{
/*
				const char *pName = pStyle->Attribute("id");
				const char *pParent = pStyle->Attribute("parent");

				HKWidgetStyle &style = sStyles.Create(pName);
				style.name = pName;
				style.parent = pParent;
*/
				xml.onEndTag["Property"] = (in Element e)
				{
					const(string)* pPropertyName = "id" in e.tag.attr;
					assert(pPropertyName, "Expected 'id=...'. Property name is not defined!");
/*
					const char *pValue = pProperty->Value();

					Property &p = style.properties.push();
					++style.numProperties;

					p.property = pPropertyName;
					p.property = pValue;
*/
				};
				xml.onEndTag["Properties"] = (in Element e)
				{
					foreach(a; e.tag.attr)
					{
						a;
/*
						Property &p = style.properties.push();
						++style.numProperties;

						p.property = pProp->Name();
						p.value = pProp->Value();

						pProp = pProp->Next();
*/
					}
				};
				xml.parse();
			};
			xml.parse();
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
			return false;
		}

		MFHeap_Free(file);
		return true;
	}

	static WidgetStyle* findStyle(const(char)[] style)
	{
		return style in styles ? styles[style] : null;
	}

	@property const(Property)[] properties() const { return _properties; }

	void apply(Widget widget)
	{
		if(!parent.length)
		{
			// apply parent properties
			WidgetStyle* pStyle = findStyle(parent);
			if(pStyle)
				pStyle.apply(widget);
		}

		// apply properties
		foreach(p; properties)
			widget.setProperty(p.property, p.value);
	}

protected:
	struct Property
	{
		string property;
		string value;
	}

	string name;
	string parent;

	Property[] _properties;

	__gshared WidgetStyle*[string] styles;
}
