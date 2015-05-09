module sound.sound;

struct Sound
{
	uint sampleRate;
	uint numChannels;
	float[] samples;
}

enum SoundFormat
{
	Wav
}

Sound load(const(char)[] filename, SoundFormat format = SoundFormat.Wav)
{
	assert(format == SoundFormat.Wav);

	import std.file;
	ubyte[] file = cast(ubyte[])read(filename);

	RIFFHeader* header = cast(RIFFHeader*)&file[0];
	file = file[RIFFHeader.sizeof..$];

	assert(header.RIFF[] == ['R','I','F','F'] && header.WAVE[] == ['W','A','V','E']);

	WAVFormatChunk* formatChunk;
	ubyte[] sampleData;

	while(file.length != 0)
	{
		WAVChunk* dataChunk = cast(WAVChunk*)&file[0];
		file = file[WAVChunk.sizeof..$];

		if(dataChunk.id[] == ['f','m','t',' '])
		{
			formatChunk = cast(WAVFormatChunk*)&file[0];
		}
		else if(dataChunk.id[] == ['d','a','t','a'])
		{
			sampleData = file[0..dataChunk.size];
		}
		file = file[dataChunk.size..$];
	}

	// convert sample data into samples
	float[] samples;
	if(formatChunk.wBitsPerSample == 8)
	{
		samples = new float[sampleData.length];
		assert(false, "TODO");
	}
	else if(formatChunk.wBitsPerSample == 16)
	{
		samples = new float[sampleData.length/2];
		short[] sam = cast(short[])sampleData;
		foreach(i, ref s; samples)
			s = sam[i]*(1.0f/short.max);
	}
	else if(formatChunk.wBitsPerSample == 24)
	{
		samples = new float[sampleData.length/3];
		assert(false, "TODO");
	}

	return Sound(formatChunk.nSamplesPerSec, formatChunk.nChannels, samples);
}

void save(Sound snd, const(char)[] filename, SoundFormat format = SoundFormat.Wav)
{
	size_t size = RIFFHeader.sizeof + WAVChunk.sizeof*2 + WAVFormatChunk.sizeof + snd.samples.length*2;
	ubyte[] buffer = new ubyte[size];
	ubyte[] file = buffer;

	RIFFHeader* header = cast(RIFFHeader*)&file[0];
	file = file[RIFFHeader.sizeof..$];

	header.RIFF[] = ['R','I','F','F'];
	header.WAVE[] = ['W','A','V','E'];
	header.size = cast(uint)(size-8);

	WAVChunk* dataChunk = cast(WAVChunk*)&file[0];
	file = file[WAVChunk.sizeof..$];

	dataChunk.id[] = ['f','m','t',' '];
	dataChunk.size = WAVFormatChunk.sizeof;

	WAVFormatChunk* formatChunk = cast(WAVFormatChunk*)&file[0];
	file = file[dataChunk.size..$];

	formatChunk.wFormatTag = 1;
	formatChunk.nChannels = cast(ushort)snd.numChannels;
	formatChunk.nSamplesPerSec = snd.sampleRate;
	formatChunk.nAvgBytesPerSec = snd.sampleRate*snd.numChannels*2;
	formatChunk.wBlockAlign = cast(ushort)(snd.numChannels*2);
	formatChunk.wBitsPerSample = 16;
	formatChunk.cbSize = 0;

	dataChunk = cast(WAVChunk*)&file[0];
	file = file[WAVChunk.sizeof..$];

	dataChunk.id[] = ['d','a','t','a'];
	dataChunk.size = cast(uint)(snd.samples.length*2);

	short[] samples = cast(short[])file;
	foreach(i; 0..snd.samples.length)
		samples[i] = cast(short)(snd.samples[i]*short.max);

	import std.file;
	write(filename, buffer);
}


private:

struct RIFFHeader
{
	ubyte[4] RIFF;
	int size;
	ubyte[4] WAVE;
}
struct WAVChunk
{
	ubyte[4] id;
	int size;
}
align(1) struct WAVFormatChunk
{
	align(1):
	short wFormatTag;
	ushort nChannels;
	uint nSamplesPerSec;
	uint nAvgBytesPerSec;
	ushort wBlockAlign;
	ushort wBitsPerSample;
	ushort cbSize; 
}
