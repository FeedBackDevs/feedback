module db.chart.part;

import db.chart.track : Track, Event, Difficulty;
import std.algorithm : canFind;

struct Part
{
	string part;
	Event[] events;			// events for the entire part (animation, etc)
	Variation[] variations;	// variations for the part (different versions, instrument variations (4/5/pro drums, etc), customs...

	string[] types()
	{
		string[] types;
		foreach (ref v; variations)
		{
			if (!types.canFind!((a, b) => a[] == b[])(v.type))
				types ~= v.type;
		}
		return types;
	}
	string[] uniqueVariations()
	{
		string[] vars;
		foreach (ref v; variations)
		{
			if (!vars.canFind!((a, b) => a[] == b[])(v.name))
				vars ~= v.name;
		}
		return vars;
	}
	string[] variationsForType(string type)
	{
		string[] vars;
		foreach (ref v; variations)
		{
			if (v.type[] != type)
				continue;
			if (!vars.canFind!((a, b) => a[] == b[])(v.name))
				vars ~= v.name;
		}
		return vars;
	}
}

struct Variation
{
	string type;
	string name;
	Track[] difficulties;	// sequences for each difficulty

	bool bHasCoopMarkers;	// GH1/GH2 style co-op (players take turns)

	Difficulty nearestDifficulty(Difficulty difficulty)
	{
		import std.algorithm : min, max;

		if (!difficulties)
			return difficulty;

		int lower = -1, higher = -1;
		foreach (d; difficulties)
		{
			if (d.difficulty == difficulty)
				return difficulty;
			if (d.difficulty < difficulty)
				lower = max(lower, cast(int)d.difficulty);
			else if (d.difficulty > difficulty)
				higher = min(higher, cast(int)d.difficulty);
		}
		if (lower != -1)
			return cast(Difficulty)lower;
		return cast(Difficulty)higher;
	}
}
