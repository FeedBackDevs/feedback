module db.ui.layoutdescriptor;

import db.game;
import db.lua : lua;
import db.ui.ui;
import db.ui.widget;
import db.ui.widgetstyle;
import db.ui.widgets.layout;
import db.ui.widgets.prefab;

import fuji.dbg;
import fuji.heap;
import fuji.filesystem;
import fuji.string;

import std.xml;
import std.algorithm;
import std.ascii;
import std.range;
import std.string;

import luad.base : nil;
import luad.state;
import luad.table : LuaTable;
import luad.lfunction : LuaFunction;

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


	Widget spawn(Widget parent = null)
	{
		if (root)
			return spawn(root, parent, null);
		return null;
	}

	Widget spawnWithEnvironment(LuaTable environment, Widget parent = null)
	{
		if (root)
			return spawn(root, parent, &environment);
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

	Widget spawn(Node* node, Widget parent, LuaTable* environment)
	{
		// create widget
		Widget widget = UserInterface.createWidget(node.type);
		if (!widget)
			return null;

		// set the environment, if there was one
		if (environment)
			widget.environment = *environment;

		// assign to parent
		if (parent)
			parent.addChild(widget);

		try
		{
			// apply properties
			bool isPrefab = cast(Prefab)widget !is null;
			foreach (ref a; node.attributes)
			{
				string value = a.value;

				// HAX: paths need to be corrected relative to the location of the source
				if (isPrefab && a.property[] == "prefab")
					value = makePath(filepath, value);

				widget.setProperty(a.property, value);
			}

			// spawn children
			foreach (c; node.children)
				spawn(c, widget, null);

			// execute script
			if (node.script)
			{
				try
				{
					LuaFunction f = Game.instance.lua.loadString(node.script);
					LuaTable* env = widget.getEnvironment();
					if (env)
						f.setEnvironment(*env);
					f.call();
				}
				catch (Exception e)
					MFDebug_Warn(2, "Script error: " ~ e.msg);
			}
		}
		catch (Exception e)
		{
			// construction failed, remove broken child...
			if (parent)
				parent.removeChild(widget);
			return null;
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
				const(string)* file = "src" in xml.tag.attr;
				if (file && *file)
				{
					string fn = makePath(filepath, *file);
					string source = MFFileSystem_LoadText(fn).assumeUnique;
					if (source)
						node.script ~= source;
				}
			}
			else if (!icmp(xml.tag.name, "style"))
			{
				// load external script...
				const(string)* file = "src" in xml.tag.attr;
				if (file && *file)
				{
//					WidgetStyle style = WidgetStyle.loadStylesFromXML(*file);
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
		xml.onEndTag["script"] = (in Element e)
		{
			node.script ~= e.text;
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
