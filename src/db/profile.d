module db.profile;

import db.sequence;


struct Score
{
	struct Record
	{
		int score;
		int numPlays;
	}

	int Score(Part part, Difficulty difficulty)
	{
		return score[sequenceIndex(part, difficulty)].score;
	}

	Record[NumSequences] score;
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
