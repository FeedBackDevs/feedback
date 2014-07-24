module db.tools.factory;

import db.tools.delegatethunk;

import fuji.dbg;

import std.traits;

struct Factory(T)
{
	static if(is(T == class))
		alias RT = T;
	else
		alias RT = T*;

	alias RT delegate(const(char)[] typeName) CreateDelegate;
	alias RT function(const(char)[] typeName) CreateFunc;

	bool registerType(const(char)[] name, CreateDelegate createDelegate)
	{
		if(name in factory)
		{
			MFDebug_Log(2, "Already Registered: " ~ name);
			return false;
		}

		factory[name] = createDelegate;
		return true;
	}

	bool registerType(const(char)[] name, CreateFunc createFunc)
	{
		if(name in factory)
		{
			MFDebug_Log(2, "Already Registered: " ~ name);
			return false;
		}

		factory[name] = DelegateThunk!CreateFunc(createFunc);
		return true;
	}

	bool registerType(T)(const(char)[] name = T.stringof)
	{
		static Type Create(Type)(const(char)[] name)
		{
			return new Type;
		}

		return registerType(name, &Create!T);
	}

	T create(const(char)[] typeName)
	{
		if(typeName !in factory)
			throw new Exception(typeof(this).stringof ~ ".create(): Type '" ~ typeName.idup ~ "' not registered");
		return factory[typeName](typeName);
	}

	bool exists(const(char)[] typeName)
	{
		return (typeName in factory) != null;
	}

private:
	CreateDelegate[string] factory;
}
