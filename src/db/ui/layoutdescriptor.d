module db.ui.layoutdescriptor;

import db.game;
import db.ui.ui;
import db.ui.widget;
import db.ui.widgets.layout;

import fuji.dbg;
import fuji.heap;
import fuji.filesystem;

import std.xml;
import std.algorithm;
import std.ascii;
import std.range;

import luad.state;

class LayoutDescriptor
{
public:
	this(const(char)[] filename = null)
	{
		if(filename)
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

		char[] file = cast(char[])MFFileSystem_Load(filename);
		if(!file)
			return false;

		try
		{
			auto xml = new DocumentParser(file.idup);
			root = parseElement(xml);
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
			return false;
		}

		MFHeap_Free(file);
		return true;
	}


	Widget spawn()
	{
		if(root)
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
	}

	Node* root;

	Widget spawn(Node* node)
	{
		// create widget
		Widget widget = UserInterface.createWidget(node.type);
		if(!widget)
			return null;

		// apply properties
		foreach(ref a; node.attributes)
			widget.setProperty(a.property, a.value);

		// spawn children
		foreach(c; node.children)
		{
			Widget child = spawn(c);
			if(child)
			{
				Layout layout = cast(Layout)widget;
				layout.addChild(child);
			}
		}

		return widget;
	}

	void destroyNode(Node* node)
	{
		if(!node)
			return;

		// destroy the child nodes
		foreach(c; node.children)
			destroyNode(c);

		// and free this node
//		MFHeap_Free(node);
	}

	static Node* parseElement(ElementParser xml)
	{
		Node* node = new Node;

		node.type = xml.tag.name;

		foreach(p, v; xml.tag.attr)
			node.attributes ~= Node.Attribute(p, v);

		xml.onStartTag[null] = (ElementParser xml)
		{
			Node* child = parseElement(xml);
			if(child)
				node.children ~= child;
		};

		xml.onPI((string text) {
			if(text.empty || isWhite(text[0]))
				return;
			string tag = text.splitter.front;
			if(tag == "lua")
				parseLuaScript(text.drop(tag.length));
			else
				MFDebug_Warn(2, "Unsupported script language: " ~ tag);
		});

		xml.parse();

		return node;
	}

	static void parseLuaScript(string text)
	{
		// NOTE: should we run when spawn, or when we load?
		// if we run when spawn, then global state may be clobbered each spawn...

		// run the script...
		try
		{
			Game.instance.lua.doString(text);
		}
		catch(Exception e)
		{
			MFDebug_Warn(2, "Script error: " ~ e.msg);
		}
	}
}
