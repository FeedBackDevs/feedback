module db.lua;

import db.ui.widget;
import db.ui.widgetevent;

import fuji.dbg;
import fuji.vector;

import luad.all;

struct LuaDelegate
{
	this(LuaFunction func) { d = func; }
	this(const(char)[] func) { d = lua.loadString(func); }

	void opCall(Widget widget, const(WidgetEventInfo)* ev) { d.call(); }
	@property auto getDelegate() pure nothrow { return &opCall; }

private:
	LuaFunction d;
}


LuaState initLua()
{
	lua = new LuaState;
	lua.openLibs();

	lua["print"] = &luaPrint;
	lua["error"] = &luaError;
	lua["warn"] = &luaWarn;
	lua["log"] = &luaLog;

//	registerStruct!(MFVector, "Vector")();

//	lua.registerType!MFVector();
//	lua.registerType!Widget();
//	lua.registerType!WidgetEventInfo();

	return lua;
}

void registerStruct(S, string name = S.stringof)()
{
	
}

void registerClass(S, string name = S.stringof)()
{

}

private:

LuaState lua;

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
