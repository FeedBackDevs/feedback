module db.profile;

import fuji.vector;

import luad.base : noscript;

class Profile
{
	struct Settings
	{
		MFVector colour = MFVector.red;

		bool bLefty = false;
		bool bAllDrumLanes = false;
	}

	// login/logout
	// read/write profile
	// personal settings/preferences
	// etc


	// TODO: manage user profiles somehow...
	// FaceBook connect? Google accounts? Steam? OpenFeint? Etc...

	string name;

	// preferences/settings
	Settings settings;

@noscript:
	struct Score
	{
		struct Record
		{
			int score;
			int numPlays;
		}

		int Score(string part, int variation, int difficulty)
		{
			return variations[part][variation][difficulty].score;
		}

		// [numDifficulties][numVariations][Part.Count]
		Record[][][string] variations;
	}

	Score[string] scores;	// scores for songs (by song name)
}
