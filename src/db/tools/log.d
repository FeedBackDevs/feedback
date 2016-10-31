module db.tools.log;

public import fuji.vector;
import fuji.fuji;
import fuji.font;
import fuji.system;

public import std.string;
public import std.conv;

enum float LogDisplayTime = 3;
enum float TextHeight = 20;

void WriteLog(const(char)[] text, MFVector colour = MFVector.white)
{
	MFDebug_Log(0, text);
//	auto s = Stringz!(256)(text);
//	messages ~= Message(colour, LogDisplayTime, s);
}

void DrawLog()
{
	float y = 10;
	for (size_t i=0; i<messages.length;)
	{
		Message* m = &messages[i];

		m.time -= MFSystem_GetTimeDelta();
		if (m.time <= 0)
		{
			messages = messages[1..$];
			continue;
		}

		MFVector colour = m.colour;
		colour.w = m.time < 1 ? m.time : 1;
		MFFont_DrawText2(null, 10, y, TextHeight, colour, m.text);
		y += TextHeight;

		++i;
	}
}

private:

struct Message
{
	MFVector colour;
	float time;
	const(char)* text;
}

Message[] messages;
