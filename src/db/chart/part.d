module db.chart.part;

import db.chart.track : Track, Event;

struct Part
{
	string part;
	Event[] events;			// events for the entire part (animation, etc)
	Variation[] variations;	// variations for the part (different versions, instrument variations (4/5/pro drums, etc), customs...
}

struct Variation
{
	string type;
	string name;
	Track[] difficulties;	// sequences for each difficulty

	bool bHasCoopMarkers;	// GH1/GH2 style co-op (players take turns)
}
