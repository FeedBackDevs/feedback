module db.tools.stringbuilder;

import fuji.string;

import std.utf;
import std.traits;

struct StringBuilder(C) if(isSomeChar!C)
{
	alias text this;

	bool opCast(bool b)() const pure nothrow @nogc
	{
		return _length != 0;
	}

	void opAssign(const(char)[] s) pure nothrow
	{
		text = s;
	}
	void opOpAssign(string op)(const(char)[] s) pure nothrow if(op == "~")
	{
		replace(_length, 0, s);
	}
	void opOpAssign(string op)(dchar c) pure if(op == "~")
	{
		static if(is(C == char) || is(C == wchar))
		{
			enum N = is(C == char) ? 4 : 2;
			C[N] e;
			size_t l = encode(e, c);
		}
		else static if(is(C == dchar))
		{
			dchar* e = &c;
			size_t l = 1;
		}
		replace(_length, 0, e[0..l]);
	}

	@property size_t length() const pure nothrow @nogc { return _length; }

	@property const(char)[] text() const pure nothrow @nogc { return buffer[0..length]; }
	@property void text(const(char)[] text) pure nothrow
	{
		if(buffer.length < text.length)
			increase(text.length);
		_length = text.length;
		buffer[0 .. _length] = text[];
	}

	void truncate(size_t len) pure nothrow @nogc
	{
		_length = len < _length ? len : _length;
	}

	void insert(size_t offset, const(char)[] s) pure nothrow
	{
		replace(offset, 0, s);
	}
	void insert(size_t offset, dchar c) pure
	{
		static if(is(C == char) || is(C == wchar))
		{
			enum N = is(C == char) ? 4 : 2;
			C[N] e;
			size_t l = encode(e, c);
		}
		else static if(is(C == dchar))
		{
			dchar* e = &c;
			size_t l = 1;
		}
		replace(offset, 0, e[0..l]);
	}

	void replace(size_t offset, size_t subString_length, const(char)[] s) pure nothrow
	{
		assert(offset <= _length, "Offset out of range");
		assert(offset + subString_length <= _length, "Sub-string _length too long");

		ptrdiff_t move = s.length - subString_length;
		if(move)
		{
			size_t newLen = _length + move;
			if(move > 0)
			{
				if(buffer.length < newLen)
					increase(newLen);
				size_t start = offset + move;
				for(size_t i = newLen-1; i >= start; --i)
					buffer[i] = buffer[i-move];
			}
			else
			{
				size_t start = offset + s.length;
				for(size_t i = start; i < newLen; ++i)
					buffer[i] = buffer[i-move];
			}
			_length = newLen;
		}
		buffer[offset .. offset + s.length] = s[];
	}
	void replace(size_t offset, size_t subString_length, dchar c) pure
	{
		static if(is(C == char) || is(C == wchar))
		{
			enum N = is(C == char) ? 4 : 2;
			C[N] e;
			size_t l = encode(e, c);
		}
		else static if(is(C == dchar))
		{
			dchar* e = &c;
			size_t l = 1;
		}
		replace(offset, subString_length, e[0..l]);
	}

	void remove(size_t offset, size_t _length) pure nothrow
	{
		replace(offset, _length, null);
	}

private:
	size_t _length;
	C[] buffer;

	void increase(size_t at_least) pure nothrow
	{
		size_t allocated = buffer.length;
		if(allocated == 0)
			allocated = at_least*4;
		else
		{
			while(allocated <= at_least)
				allocated *= 4;
		}

		C[] b = new C[allocated];
		b[0 .. _length] = buffer[0 .. _length];
		buffer = b;
	}
}
