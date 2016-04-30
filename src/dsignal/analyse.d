module dsignal.analyse;

import std.range;

auto detectPeaks(R)(R[] range, ElementType!R threshold)
{
	alias E = ElementType!R;

	struct DetectPeaks
	{
		R range;
		E threshold;
		size_t offset;

		@property bool empty() const { return offset >= range.length-1; }
		@property E front() { return range[offset]; }
		void popFront()
		{
			if(empty)
				return;
			foreach(i; offset+1 .. range.length-1)
			{
				E s = range[i];
				if(s < threshold)
					continue;
				if(s >= range[i-1] && s >= range[i+1])
				{
					offset = i;
					break;
				}
			}
		}

		@property auto save() { return this; }
	}

	auto r = DetectPeaks(range, threshold, 0);
	r.popFront();
	return r;
}

auto interpolatePeaks(R)(R[] range, ElementType!R threshold, R[] phase)
{
	alias E = ElementType!R;

	struct DetectPeaks
	{
		R range;
		E threshold;
		size_t offset;
		E freq, amp, phase;

		@property bool empty() const { return offset >= range.length-1; }
		@property E front()
		{
			return range[offset];
		}
		void popFront()
		{
			if(empty)
				return;
			foreach(i; offset+1 .. range.length-1)
			{
				E s = range[i];
				if(s < threshold)
					continue;
				if(s >= range[i-1] && s >= range[i+1])
				{
					offset = i;
					break;
				}
			}
		}

		@property auto save() { return this; }
	}

	auto r = DetectPeaks(range, threshold, 0);
	r.popFront();
	return r;
}
