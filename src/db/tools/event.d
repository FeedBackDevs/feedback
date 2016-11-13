module db.tools.event;

import db.lua;

import fuji.dbg;

import luad.all;

import std.traits;
import std.string;
import std.algorithm;

struct EventInfo
{
	void *pSender;
	void *pUserData;
}

struct Event(Args...)
{
	alias EventArgs = Args;
	alias Handler = void delegate(Args);

	final T opCast(T)() if (is(T == bool)) { return _subscribers.length != 0; }

	final @property bool empty() const pure nothrow @nogc { return _subscribers.length == 0; }
	final @property inout(Handler)[] subscribers() inout pure nothrow @nogc { return _subscribers; }

	void opCall(Args args) const nothrow
	{
		signal(args);
	}

	void opOpAssign(string op)(Handler handler) pure nothrow if (op == "~")
	{
		subscribe(handler);
	}

	void signal(Args args) const nothrow
	{
		foreach (s; _subscribers)
		{
			try
			{
				s(args);
			}
			catch (Exception e)
			{
				MFDebug_Warn(2, "Unhandled exception in event handler.".ptr);
			}
		}
	}

	void subscribe(Handler handler) pure nothrow
	{
		if (!handler)
			return;

		foreach (h; _subscribers)
		{
			if (h == handler)
				return;
		}

		_subscribers ~= handler;
	}

	void unsubscribe(Handler handler) pure nothrow @nogc
	{
		foreach (i; 0.._subscribers.length)
		{
			if (_subscribers[i] == handler)
			{
				_subscribers[i .. $-1] = _subscribers[i+1 .. $];
				_subscribers = _subscribers[0 .. $-1];
				return;
			}
		}
	}

private:
	Handler[] _subscribers;
}

void bindEvent(alias event)(const(char)[] handler)
{
	alias EventType = typeof(event);
	EventType.Handler d;

	LuaObject obj = getLuaObject(handler);
	if (obj.type == LuaType.Function)
	{
		LuaFunction f = obj.to!LuaFunction;
		auto ld = new LuaDelegate!(EventType.EventArgs)(f);
		d = ld.getDelegate;
	}
	if (!d)
	{
		// HACK: this should be split into multiple functions
		import db.ui.ui;

		// search for registered D handler
//		d = UserInterface.getEventHandler(handler.strip);
	}
	if (!d)
	{
		// treat the text as lua code
		try
		{
			auto ld = new LuaDelegate!(EventType.EventArgs)(handler);
			d = ld.getDelegate;
		}
		catch (Exception e)
			MFDebug_Warn(2, "Couldn't create Lua delegate: " ~ e.msg);
	}

	if (d)
		event ~= d;
}
