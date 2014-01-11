module db.profile;

import db.sequence;


struct Score
{
	struct Record
	{
		int score;
		int numPlays;
	}

	int Score(Part part, int variation, int difficulty)
	{
		return variations[part][variation][difficulty].score;
	}

	// [numDifficulties][numVariations][Part.Count]
	Record[][][Part.Count] variations;
}

class Profile
{
	// login/logout
	// read/write profile
	// personal settings/preferences
	// etc


	// TODO: manage user profiles somehow...
	// FaceBook connect? Google accounts? Steam? OpenFeint? Etc...

	string name;

	Score[string] scores;	// scores for songs (by song name)

	// preferences/settings
	bool bLefty;

	// TODO: visual stuff?
	// colours, models, etc...
}
