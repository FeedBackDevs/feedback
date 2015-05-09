module dsignal.window;

import std.math;
import std.traits;

@safe: pure: nothrow:

enum WindowType
{
	Rectangular,
	Triangle,
	Hann,
	Hamming,
	Blackman,
	BlackmanHarris
}


T[] generateWindow(T)(WindowType type, size_t N)
{
	T[] w = new T[N];
	generateWindow(type, w);
	return w;
}

@nogc:

void generateWindow(T)(WindowType type, T[] output)
{
	size_t N = output.length;
	foreach(i; 0..N)
		output[i] = cast(T)(sampleWindow(type, i, N));
}

double sideLobeAttenuation(WindowType type)
{
	final switch(type) with(WindowType)
	{
		case Rectangular:		return -13.0;
		case Triangle:			return -27.0;
		case Hann:				return -32.0;
		case Hamming:			return -42.0;
		case Blackman:			return -58.0;
		case BlackmanHarris:	return -92.0;
	}
}

double sampleWindow(WindowType type, size_t n, size_t N)
{
	final switch(type) with(WindowType)
	{
		case Rectangular:
			return 1.0;
		case Triangle:
			return 1.0-abs((2.0*n-(N-1)) / (N-1));
		case Hann:
			return 0.5 - 0.5*cos((2*PI*n) / (N-1));
		case Hamming:
			return 0.54 - 0.46*cos((2*PI*n) / (N-1));
		case Blackman:
		{
			double phi = (2*PI*n) / (N-1);
			return 0.42 - 0.5*cos(phi) + 0.08*cos(2*phi);
		}
		case BlackmanHarris:
		{
			double phi = (2*PI*n) / (N-1);
			return 0.422323 - 0.49755*cos(phi) + 0.07922*cos(2*phi);
		}
	}
}

template Window(WindowType type, size_t N, T = double) if(isFloatingPoint!T)
{
	immutable T[] Window = generateWindow!T(type, N);
}
