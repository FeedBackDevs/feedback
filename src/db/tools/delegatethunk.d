module db.tools.delegatethunk;

import std.traits;

struct DelegateThunk(F)
{
	alias D = ReturnType!F delegate(ParameterTypeTuple!F);
	alias d this;

	D d;
	@property inout(F) f() inout pure nothrow { return cast(inout(F))d.ptr; }

	this(F f)
	{
		d = &thunk;
		d.ptr = cast(typeof(this)*)f;
	}

private:
	// expect the function pointer in the 'this' pointer and call it
	ReturnType!F thunk(ParameterTypeTuple!F args)
	{
		F func = cast(F)&this;
		return func(args);
	}
}
