module db.tools.tokeniser;

import std.algorithm;

struct Tokeniser(string Separators = " \t\r\n", DelimiterPairs...)
{
	this(string s)
	{
		text = s;
		popFront();
	}

	string front() const pure nothrow { return token; }
	bool empty() const pure nothrow { return !token; }
	void popFront()
	{
		token = null;
		while(text.length && Separators.canFind(text[0]))
			text = text[1..$];
		if(!text.length)
			return;
		size_t offset;
		int depth = 0;
		while(offset < text.length && (depth > 0 || !Separators.canFind(text[offset])))
		{
			foreach(d; DelimiterPairs)
			{
				if(text[offset] == d[0])
					++depth;
				else if(text[offset] == d[1])
					--depth;
			}

			++offset;
		}
		token = text[0..offset];
		text = text[offset..$];
	}
	string getFront()
	{
		string f = token;
		popFront();
		return f;
	}

	string token;
	string text;
}
