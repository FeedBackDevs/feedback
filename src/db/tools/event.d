module db.tools.event;

import std.traits;

struct EventInfo
{
	void *pSender;
	void *pUserData;
}

struct Event(Args...)
{
	alias Handler = void delegate(Args);

	Handler[] subscribers;

	@property empty() const pure nothrow { return subscribers.length == 0; }

	void opCall(Args args)
	{
		signal(args);
	}

	void opOpAssign(string op)(Handler handler) pure nothrow if(op == "~")
	{
		subscribe(handler);
	}

	void signal(Args args)
	{
		foreach(s; subscribers)
			s(args);
	}

	void subscribe(Handler handler) pure nothrow
	{
		if(!handler)
			return;

		foreach(h; subscribers)
		{
			if(h == handler)
				return;
		}

		subscribers ~= handler;
	}

	void unsubscribe(Handler handler) pure nothrow
	{
		foreach(i; 0..subscribers.length)
		{
			if(subscribers[i] == handler)
			{
				subscribers = subscribers[0..i] ~ subscribers[i+1 .. subscribers.length];
				return;
			}
		}
	}
}
