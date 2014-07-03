module db.tools.filetypes;

import std.string;
import std.algorithm : canFind;
import std.path;


static immutable imageTypes = [ ".png", ".jpg", ".jpeg", ".tga", ".dds", ".bmp" ];
static immutable musicTypes = [ ".ogg", ".mp3", ".flac", ".wav" ];
static immutable videoTypes = [ ".avi", ".mp4", ".mkv", ".mpg", ".mpeg" ];


bool isImageFile(const(char)[] filename)
{
	return canFind(imageTypes, filename.extension.toLower);
}

bool isAudioFile(const(char)[] filename)
{
	return canFind(musicTypes, filename.extension.toLower);
}

bool isVideoFile(const(char)[] filename)
{
	return canFind(videoTypes, filename.extension.toLower);
}
