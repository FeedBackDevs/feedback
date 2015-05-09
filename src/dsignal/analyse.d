module dsignal.analyse;

import std.range;

auto detectPeaks(R)(R[] range, ElementType!R threshold)
{
	alias E = ElementType!R;

	struct DetectPeaks
	{
		R range;
		E threshold;
		E peak;

		@property bool empty() const { return range.empty; }
		@property E front() { return peak; }
		void popFront()
		{
			if(empty)
				return;
 			E s[3];
			s[2] = range.front;
			range.popFront;

			while(!range.empty)
			{
				s[0] = s[1];
				s[1] = s[2];
				s[2] = range.front;
				range.popFront;

				if(s[1] > threshold)
				{
				   // check if we have a peak...
				}
			}
		}

		@property auto save() { return this; }
	}

	auto r = DetectPeaks(range, threshold);
	r.popFront();
	return r;
}
