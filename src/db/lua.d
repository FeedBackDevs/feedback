module db.lua;

public import luad.base;
public import luad.table;

import db.ui.widget;
import db.ui.widgets.label;
import db.ui.widgets.button;
import db.ui.widgets.prefab;
import db.ui.widgets.layout;
import db.ui.widgets.frame;
import db.ui.widgets.linearlayout;
import db.ui.widgets.textbox;
import db.ui.widgets.listbox;
import db.ui.listadapter;
import db.ui.ui;
import db.game;
import db.player;
import db.profile;

import fuji.dbg;
import fuji.types;
import fuji.vector;
import fuji.matrix;
import fuji.quaternion;
import fuji.string;
import fuji.system;
import fuji.input;

import luad.all;
import luad.stack;
import luad.error;
import luad.c.lua;

import std.string;
import std.range;
import std.algorithm.iteration : splitter;


struct LuaDelegate(Args...)
{
	this(LuaFunction func) { d = func; }
	this(const(char)[] func) { d = lua.loadString(func); }

	void opCall(Args args)
	{
		try
		{
			d.call(args);

			// TODO: check return value, if we returned a function, then call it with (widget, ev)
		}
		catch(Exception e)
		{
			MFDebug_Error(e.msg);
		}
	}
	@property auto getDelegate() pure nothrow { return &opCall; }

private:
	LuaFunction d;
}

class LuaArrayAdaptor : ListAdapter
{
	this(LuaTable array, LuaFunction getItem, LuaFunction updateItem)
	{
		this.array = array;
		this.getItem = getItem;
		this.updateItem = updateItem;

		// TODO: we can theoretically implement __index and __newindex in a metatable to forward to the given array, and capture add/remove/change event signals
	}

	override size_t length() const
	{
		// BRUTAL HACK: LuaD doesn't handle 'const'
		auto _this = cast(Unqual!(typeof(this)))this;
		return _this.array.length;
	}

protected:
	LuaTable array;
	LuaFunction getItem;
	LuaFunction updateItem;

	override Widget getItemView(int item)
	{
		// Lua arrays are 1-based
		item += 1;
		return getItem.call!Widget(array[item]);
	}

	override void updateItemView(int item, Widget layout)
	{
		// Lua arrays are 1-based
		item += 1;
		updateItem.call(array[item], layout);
	}
}


void registerType(S, string name = S.stringof)()
{
	lua.set(name, lua.registerType!S());
}

LuaState initLua()
{
	static extern(C) void* alloc(void* ud, void* ptr, size_t osize, size_t nsize)
	{
		import fuji.heap;
		if(nsize == 0)
		{
			if(ptr)
			{
				MFHeap_Free(ptr);
				ptr = null;
			}
		}
		else
			ptr = MFHeap_Realloc(ptr[0..osize], nsize).ptr;
		return ptr;
	}

	static void panic(LuaState state, in char[] error)
	{
		MFDebug_Error(error);
		throw new LuaErrorException(error.idup);
	}

//	lua = new LuaState(&alloc);
	lua = new LuaState();
	lua.setPanicHandler(&panic);

	lua.openLibs();

	lua["print"] = &luaPrint;
	lua["error"] = &luaError;
	lua["warn"] = &luaWarn;
	lua["log"] = &luaLog;

	lua.doString(luaCode);

	lua["quit"] = &MFSystem_Quit;
	lua["startPerformance"] = &Game.instance.startPerformance;
	lua["endPerformance"] = &Game.instance.endPerformance;
	lua["pausePerformance"] = &Game.instance.pausePerformance;

	lua["addPlayer"] = &Game.instance.addPlayer;
	lua["removePlayer"] = &Game.instance.removePlayer;

	lua["library"] = Game.instance.songLibrary;
	lua["ui"] = Game.instance.ui;

	// Fuji enums
	registerType!MFKey();

	// Fuji types
	registerType!(MFRect, "Rect")();
	registerType!(MFVector, "Vector")();
	registerType!(MFQuaternion, "Quaternion")();
	registerType!(MFMatrix, "Matrix")();

	// Game objects
	registerType!Player();
	registerType!Profile();

	// UI
	registerType!(LuaArrayAdaptor, "ArrayAdapter")();

	// Widgets
	registerType!Widget();
	registerType!Label();
	registerType!Button();
	registerType!Prefab();
	registerType!Frame();
	registerType!LinearLayout();
	registerType!Textbox();
	registerType!Listbox();
//	registerType!Selectbox();

	return lua;
}

LuaTable createTable()
{
	lua_newtable(lua.state);
	return popValue!LuaTable(lua.state);
}

void doFile(const(char)[] file)
{
	import fuji.filesystem;
	char[] source = MFFileSystem_LoadText(file);
	lua.doString(source);
}

bool isValidIdentifier(const(char)[] handler)
{
	import std.ascii;

	if(handler.length == 0)
		return false;

	if(!handler[0].isAlpha && !(handler[0] == '_'))
		return false;

	foreach(i, c; handler[1..$])
	{
		if(c == '.')
			return handler[i+1..$].isValidIdentifier;
		else if(!c.isAlphaNum && c != '_')
			return false;
	}
	return true;
}

LuaObject getLuaObject(const(char)[] identifier)
{
	auto ident = identifier.strip;

	LuaObject obj;

	// if the string is an identifier
	if(ident.isValidIdentifier)
	{
		// search for lua global
		LuaTable t = lua.globals;
		foreach(token; ident.splitter('.'))
		{
			if(!t.isNil)
			{
				obj = t[token];
				if(obj.type == LuaType.Table)
					t = obj.to!LuaTable;
				else
					t.release();
			}
			else
			{
				obj.release();
				break;
			}
		}
	}
	return obj;
}


package:

LuaState lua;


private:

__gshared string luaCode = q{
  function tprint(tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
    	if k ~= "package" and k ~= "_G" then
      formatting = string.rep("  ", indent) .. k .. ": "
      if type(v) == "table" then
        print(formatting)
        tprint(v, indent+1)
      else
        print(formatting .. tostring(v))
      end
      end
    end
  end
};

extern(C) void luaPrint(LuaObject[] params...)
{
	string msg;
	if(params.length > 0)
	{
		foreach(param; params[0..$-1])
			msg ~= param.toString() ~ '\t';
		msg ~= params[$-1].toString();
	}
	MFDebug_Message(msg);
}

extern(C) void luaError(LuaObject[] params...)
{
	string msg;
	if(params.length > 0)
	{
		foreach(param; params[0..$-1])
			msg ~= param.toString() ~ '\t';
		msg ~= params[$-1].toString();
	}
	MFDebug_Error(msg);
}

extern(C) void luaWarn(int level, LuaObject[] params...)
{
	string msg;
	if(params.length > 0)
	{
		foreach(param; params[0..$-1])
			msg ~= param.toString() ~ '\t';
		msg ~= params[$-1].toString();
	}
	MFDebug_Warn(level, msg);
}

extern(C) void luaLog(int level, LuaObject[] params...)
{
	string msg;
	if(params.length > 0)
	{
		foreach(param; params[0..$-1])
			msg ~= param.toString() ~ '\t';
		msg ~= params[$-1].toString();
	}
	MFDebug_Log(level, msg);
}
