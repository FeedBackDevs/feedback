module db.chart.part;

import db.chart.track : Track, Event, Difficulty;
import std.algorithm : canFind, sort, SwapStrategy;

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
			if (v.type[] == type)
				vars ~= v.name;
		}
		return vars;
	}
	string[] variationTypesFor(string name)
	{
		string[] vars;
		foreach (ref v; variations)
		{
			if (v.name[] == name)
				vars ~= v.type;
		}
		return vars;
	}

	Variation* variation(const(char)[] variationType, const(char)[] variationName, bool create = false)
	{
		foreach (ref v; variations)
		{
			if (v.type[] == variationType && v.name[] == variationName)
				return &v;
		}
		if (create)
		{
			variations ~= Variation(variationType.idup, variationName.idup);
			return &variations[$-1];
		}
		return null;
	}

	Variation* bestVariationForType(const(char)[] variationType, const(char)[] variationName)
	{
		// TODO: work on logic for selection of variation? (currently, selects unnamed or first variation in lieu)
		Variation *pVar = null;
		foreach (ref v; variations)
		{
			if (v.type[] == variationType)
			{
				if (v.name[] == variationName)
					return &v;
				if (!pVar || v.name == null)
					pVar = &v;
			}
		}
		return pVar;
	}
}

struct Variation
{
	string type;
	string name;
	Track[] difficulties;	// sequences for each difficulty

	bool bHasCoopMarkers;	// GH1/GH2 style co-op (players take turns)

	Track difficulty(Difficulty difficulty)
	{
		foreach (d; difficulties)
		{
			if (d.difficulty == difficulty)
				return d;
		}
		return null;
	}

	Difficulty nearestDifficulty(Difficulty difficulty)
	{
		import std.algorithm : min, max;

		if (!difficulties || difficulty == Difficulty.Unknown)
			return Difficulty.Unknown;

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

	void addDifficulty(Track trk)
	{
		difficulties ~= trk;
		difficulties.sort!((a, b) => a.difficulty < b.difficulty, SwapStrategy.stable);
	}
}
