module dsignal.stft;

import dsignal.fft;
import dsignal.util;

import std.complex;
import core.sys.posix.stdlib;
import std.range: retro, chain, zip;
import std.typecons;
import std.algorithm : map, copy;

nothrow: @nogc:

alias FFTDirection = dsignal.fft.FFTDirection;

F[][] STFT(F)(const(F)[] signal, const(F)[] window, F[][] amplitude, F[][] phase, size_t hop, size_t fftSize, FFTDirection direction = FFTDirection.Forward)
{
	auto segments = segment(signal, window.length, window.length-hop);
	assert(!amplitude || amplitude.length >= segments.length, "Not enough frames in amplitude buffer");
	assert(!phase || phase.length >= segments.length, "Not enough frames in phase buffer");

	size_t samplesPerFrame = fftSize/2 + 1;
	assert(!amplitude || amplitude[0].length == samplesPerFrame, "Incorrect number of samples per frame in amplitude buffer");
	assert(!phase || phase[0].length == samplesPerFrame, "Incorrect number of samples per frame in amplitude buffer");

	// allocate a temporary fft buffer
	size_t bufferLen = Complex!F.sizeof*fftSize;
	Complex!F[] fftBuffer = cast(Complex!F[])alloca(bufferLen)[0..bufferLen];

	auto start = window[0..$/2];
	auto end = window[$/2..$];
	size_t i = 0;
	foreach(s; segments)
	{
		// prepare the fft buffer
		s.chain(literalRange!(F(0))(window.length-s.length))	// padd range with 0's
			.zip(window)										// pairs samples from signal and window
			.map!(e => Complex!F(e[0] * e[1], 0))				// sample*window and return as complex real
			.zeroPadd!true(fftSize)								// zero padd and zero phase window the buffer
			.copy(fftBuffer);									// write to the FFT buffer

		// do the fft
		FFT(fftBuffer);

		// write out positive half of FFT buffer
		if(amplitude)
			fftBuffer[0..samplesPerFrame].map!(e => std.complex.abs(e)).copy(amplitude[i]);
		if(phase)
			fftBuffer[0..samplesPerFrame].map!(e => std.complex.arg(e)).copy(phase[i]); // TODO: do this in one pass?
		++i;
	}

	return amplitude ? amplitude[0..segments.length] : phase[0..segments.length];
}

void ISTFT(F)(const F[][] amplitude, const F[][] phase, F[] signal, size_t windowWidth, size_t hop, size_t fftSize)
{
	auto segments = segment(signal, windowWidth, windowWidth-hop);
	assert(amplitude.length == phase.length && amplitude.length <= segments.length, "Output buffer too small");

	size_t numFrames = amplitude.length;

	size_t samplesPerFrame = fftSize/2 + 1;
	assert(samplesPerFrame == amplitude[0].length, "Incorrect number of samples per frame");

	// allocate a temporary fft buffer
	size_t bufferLen = Complex!F.sizeof*fftSize;
	Complex!F[] fftBuffer = cast(Complex!F[])alloca(bufferLen)[0..bufferLen];

	// initialise the output buffer
	signal[] = F(0);

	size_t middle = windowWidth/2;
	F H = F(hop);
	foreach(i; 0..numFrames)
	{
		auto a = amplitude[i];
		auto p = phase[i];

		// populate the fft buffer
		fftBuffer[0] = fromPolar(a[0], p[0]);
		foreach(j; 1..fftSize/2)
		{
			fftBuffer[j] = fromPolar(a[j], p[j]);
			fftBuffer[$-j] = fftBuffer[j].conj;
		}
		fftBuffer[fftSize/2] = fromPolar(a[fftSize/2], p[fftSize/2]);

		// do the ifft
		IFFT(fftBuffer);

		// write the signal to the output buffer
		auto output = segments[i];
		foreach(s; 0..middle)
			output[s] += fftBuffer[$-middle + s].re * H;
		foreach(s; middle..output.length)
			output[s] += fftBuffer[s - middle].re * H;
	}
}
