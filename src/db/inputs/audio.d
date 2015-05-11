module db.inputs.audio;

import db.tools.log;
import db.i.inputdevice;
import db.i.syncsource;
import db.instrument;
import db.sequence;
import db.game;

import fuji.device;
import fuji.sound;
import fuji.dbg;

import dsignal.window;
import dsignal.stft;


import fuji.texture;
import fuji.material;
import graph.plot;
import db.tools.image.image;


class Audio : InputDevice
{
	this(size_t audioDeviceIndex)
	{
		device = AudioCaptureDevice(Device(MFDeviceType.AudioCapture, audioDeviceIndex));

		frames = new float[][](NumFrames, FFTWidth/4);//2+1);
		foreach(f; frames)
			f[] = 0.0;

		// this is either vocals, or pro-guitar
		instrumentType = InstrumentType.Vocals;
		supportedParts = [ Part.Vox ];

		if(device.open() == 0)
			MFDebug_Warn(2, "Couldn't open audio capture device".ptr);
		else
			MFDebug_Log(2, "Opened audio capture device: " ~ device.name ~ " (" ~ device.id ~ ")");
	}
	~this()
	{
		device.close();
	}

	override @property long inputTime()
	{
		return Game.instance.performance.time - (deviceLatency + Game.instance.settings.micLatency)*1_000;
	}

	override void Begin(SyncSource sync)
	{
		super.Begin(sync);
		device.start(&GetSamplesCallback, cast(void*)this);
	}

	override void End()
	{
		device.stop();
	}

	override void Update()
	{
		// read audio stream, process into input sequence...

		// vox and guitar require different filtering
	}
/+
	Material GetSpectrum()
	{
		import dsignal.util;
		import std.math: log10;

		alias lRGB = Color!("rgb", double, ColorSpace.sRGB_l);
		__gshared spectrumColours = [
			lRGB(0,0,1),
			lRGB(0,1,1),
			lRGB(1,1,0),
			lRGB(1,0,0),
			lRGB(0,0,0)
		];

		if(!spectrum)
		{
			spectrum.create2D("Spectrum", cast(int)frames.length, cast(int)frames[0].length, MFImageFormat.A8R8G8B8, MFTextureCreateFlags.Dynamic);
			spectrumMat = Material("Spectrum");
		}

		MFLockedTexture map;
		if(spectrum.map(map))
		{
			size_t w = frames.length;
			size_t h = frames[0].length;
			BGRA[] pixels = cast(BGRA[])map.pData[0..w*h*BGRA.sizeof];
			foreach(y; 0..h)
			{
				size_t ly;
				if(logScale)
					ly = h-cast(size_t)((double(y)/h)^^2.0*h)-1;
				else
					ly = h-y-1;
				size_t offset = y*w;
				foreach(x; 0..w)
				{
					double e = frames[x][ly];
					pixels[offset+x] = cast(BGRA)lerpRange(clamp(20*log10(e)/200 + 1, 0, 1), spectrumColours);
				}
			}
			spectrum.unmap();
		}

//		frames.plotSpectrum.colorMap!(c => cast(BGRA)c).updateTexture(spectrum);
		return spectrumMat;
	}
+/
	Material GetSpectrum()
	{
		if(!spectrum)
		{
			spectrum.create2D(device.id~"-Spectrum", cast(int)frames.length, cast(int)frames[0].length, MFImageFormat.R_F32, MFTextureCreateFlags.Dynamic);
			spectrumMat = Material(device.id~"-Spectrum");
		}

		MFLockedTexture map;
		if(spectrum.map(map))
		{
			size_t w = frames.length;
			size_t h = frames[0].length;
			float[] pixels = cast(float[])map.pData[0..w*h*float.sizeof];
			foreach(y; 0..h)
			{
				size_t offset = y*w;
				foreach(x; 0..w)
					pixels[offset+x] = float(frames[x][y]);
			}
			spectrum.unmap();
		}

		return spectrumMat;
	}
	Material GetWaveform()
	{
		if(!waveform)
		{
			waveform.create2D(device.id~"-Waveform", 1024, 256, MFImageFormat.A8R8G8B8, MFTextureCreateFlags.Dynamic);
			waveformMat = Material(device.id~"-Waveform");
		}
		if(frames.length)
			frames[(frameIndex+frames.length-1)%frames.length].plotAmplitude(1024, 256).colorMap!(c => cast(BGRA)c).updateTexture(waveform);
		return waveformMat;
	}

private:
	AudioCaptureDevice device;
	int channel;

	// frame analysis buffer
	enum FFTWidth = 4096;
	enum WindowSize = 4001;
	enum HopSize = WindowSize/8;
	enum NumFrames = 512;

	static immutable float[WindowSize] window = generateWindow!float(WindowType.Hamming, WindowSize);

	float[][] frames;
	size_t frameIndex;

	// incoming audio buffer
	enum BufferLen = 44100;
	size_t offset, count;
	float[BufferLen] sampleData;

	// debug stuff...
	Texture waveform;
	Texture spectrum;
	Material waveformMat;
	Material spectrumMat;

nothrow @nogc:
	void GetSamples(const(float)* pSamples, size_t numSamples, int numChannels)
	{
		import std.algorithm: min;

		// this looks complicated because we're dealing with all circular buffers and shit
		if(offset + count + numSamples > BufferLen)
		{
			sampleData[0..count] = sampleData[offset..offset+count];
			offset = 0;
		}
		foreach(i; 0..numSamples)
			sampleData[offset+count+i] = pSamples[i*numChannels + channel];
		count += numSamples;

		// for each frame, take an fft
		if(count >= WindowSize)
		{
			size_t numFramesAvailable = 1 + (count - WindowSize)/HopSize;
			while(numFramesAvailable)
			{
				size_t numFrames = min(numFramesAvailable, NumFrames-frameIndex);

				STFT(sampleData[offset..offset+HopSize*numFrames+WindowSize-HopSize], window[], frames[frameIndex..frameIndex+numFrames], null, HopSize, FFTWidth);

				offset += numFrames*HopSize;
				count -= numFrames*HopSize;
				frameIndex += numFrames;
				if(frameIndex >= NumFrames)
					frameIndex -= NumFrames;
				numFramesAvailable -= numFrames;
			}
		}

	}

	static extern (C) void GetSamplesCallback(const(float)* pSamples, size_t numSamples, int numChannels, void* pUserData)
	{
		(cast(Audio)pUserData).GetSamples(pSamples, numSamples, numChannels);
	}
}

Audio[] detectAudioDevices()
{
	Audio[] devices;

	foreach(i; 0..MFDevice_GetNumDevices(MFDeviceType.AudioCapture))
		devices ~= new Audio(i);

	return devices;
}
