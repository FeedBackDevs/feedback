module dsignal.wave;

public import std.complex;
import std.math;

@safe: pure: nothrow:

Complex!F[] generateSinusoid(F)(size_t N, F periods)
{
	T[] w = new T[N];
	generateWindow(w, periods);
	return w;
}

void generateSinusoid(F)(Complex!F[] output, F periods) @nogc
{
	ptrdiff_t N = output.length;
	F t = -0.5;
	F inc = F(1)/N;
	foreach(i; 0..N)
	{
		output[i] = std.complex.expi(2*PI*periods*t);
		t += inc;
	}
}


T[] generateSinewave(T)(size_t N, T periods)
{
	T[] w = new T[N];
	generateWindow(w, periods);
	return w;
}

void generateSinewave(T)(T[] output, T periods) @nogc
{
	ptrdiff_t N = output.length;
	T t = -0.5;
	T inc = T(1)/N;
	foreach(i; 0..N)
	{
		output[i] = cos(2*PI*periods*t);
		t += inc;
	}
}


T[] generateSinewave(T)(size_t N, T freq, T sampleRate, T phase = 0, T amplitude = 1)
{
	T[] w = new T[N];
	generateWindow(w, freq, sampleRate, phase, amplitude);
	return w;
}

void generateSinewave(T)(T[] output, T freq, T sampleRate, T phase = 0, T amplitude = 1) @nogc
{
	size_t N = output.length;
	double time = N/sampleRate;
	double t = time * -0.5;
	double inc = 1/sampleRate;
	foreach(i; 0..N)
	{
		output[i] = amplitude * cos(2*PI*freq*t + phase);
		t += inc;
	}
}
