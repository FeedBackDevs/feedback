module db.ui.layoutdescriptor;

import db.game;
import db.ui.ui;
import db.ui.widget;
import db.ui.widgetstyle;
import db.ui.widgets.layout;

import fuji.dbg;
import fuji.heap;
import fuji.filesystem;
import fuji.string;

import std.xml;
import std.algorithm;
import std.ascii;
import std.range;
import std.string;

import luad.state;

class LayoutDescriptor
{
public:
	this(const(char)[] filename = null)
	{
		if (filename)
			loadFromXML(filename);
	}

	~this()
	{
		destroyNode(root);
	}

	bool loadFromXML(const(char)[] filename)
	{
		// destroy any existing descriptor
		destroyNode(root);
		this.filename = null;

		string file = MFFileSystem_LoadText(filename).assumeUnique;
		if (!file)
			return false;

		string fn = filename.idup;
		this.filename = fileName(fn);
		this.filepath = filePath(fn);

		try
		{
			auto xml = new DocumentParser(file);
			root = parseElement(xml);
		}
		catch (Exception e)
		{
			MFDebug_Error(e.msg);
			return false;
		}
		return true;
	}


	Widget spawn()
	{
		if (root)
			return spawn(root);
		return null;
	}

protected:
	struct Node
	{
		struct Attribute
		{
			string property;
			string value;
		}

		string type;
		Attribute[] attributes;
		Node*[] children;

		string script;
	}

	string filename;
	string filepath;

	Node* root;

	Widget spawn(Node* node)
	{
		// create widget
		Widget widget = UserInterface.createWidget(node.type);
		if (!widget)
			return null;

		// apply properties
		foreach (ref a; node.attributes)
			widget.setProperty(a.property, a.value);

		// execute script
		if (node.script)
		{
			try
				Game.instance.lua.doString(node.script);
			catch (Exception e)
				MFDebug_Warn(2, "Script error: " ~ e.msg);
		}

		// spawn children
		foreach (c; node.children)
		{
			Widget child = spawn(c);
			if (child)
			{
				Layout layout = cast(Layout)widget;
				layout.addChild(child);
			}
		}

		return widget;
	}

	void destroyNode(Node* node)
	{
		if (!node)
			return;

		// destroy the child nodes
		foreach (c; node.children)
			destroyNode(c);
	}

	Node* parseElement(ElementParser xml)
	{
		Node* node = new Node;

		node.type = xml.tag.name;

		foreach (p, v; xml.tag.attr)
			node.attributes ~= Node.Attribute(p, v);

		xml.onStartTag[null] = (ElementParser xml)
		{
			if (!icmp(xml.tag.name, "script"))
			{
				// load external script...
				string file = xml.tag.attr["src"];
				if (file)
				{
					string fn = makePath(filepath, file);
					string source = MFFileSystem_LoadText(fn).assumeUnique;
					if (source)
						node.script ~= source;
				}
				else
					MFDebug_Warn(2, "<script> element has no 'src' attribute. Can't load script.".ptr);
			}
			else if (!icmp(xml.tag.name, "style"))
			{
				// load external script...
				string file = xml.tag.attr["src"];
				if (file)
				{
//					WidgetStyle style = WidgetStyle.loadStylesFromXML(file);
				}
				else
					MFDebug_Warn(2, "<style> element has no 'src' attribute. Can't load styles.".ptr);
			}
			else
			{
				Node* child = parseElement(xml);
				if (child)
					node.children ~= child;
			}
		};

		xml.onPI((string text) {
			if (text.empty || isWhite(text[0]))
				return;
			string tag = text.splitter.front;
			if (tag == "lua")
				node.script ~= "\n" ~ text.drop(tag.length + 1);
			else
				MFDebug_Warn(2, "Unsupported script language: " ~ tag);
		});

		xml.parse();

		return node;
	}
}
