module db.tools.range;

import std.range;

auto getFront(R)(ref R range)
{
	auto f = range.front();
	range.popFront();
	return f;
}

T[] getFrontN(R, T = ElementType!R)(ref R range, size_t n)
{
	T[] f = range[0..n];
	range.popFrontN(n);
	return f;
}

As frontAs(As, R)(R range)
{
	assert(range.length >= As.sizeof);
	As r;
	(cast(ubyte*)&r)[0..As.sizeof] = range[0..As.sizeof];
	return r;
}

As getFrontAs(As, R)(ref R range)
{
	assert(range.length >= As.sizeof);
	As r;
	(cast(ubyte*)&r)[0..As.sizeof] = range.getFrontN(As.sizeof)[];
	return r;
}
