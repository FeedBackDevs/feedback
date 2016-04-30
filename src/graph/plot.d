module graph.plot;

import image.image;
import dsignal.util;

import std.range;
import std.traits : isFloatingPoint;
import std.algorithm : map;

struct PlotParams
{
	double min, max;
	double width = 1;
}

auto plot(R)(R data, size_t width, size_t height, PlotParams params = PlotParams.init) if(isRandomAccessRange!R && is(ElementType!R : double))
{
	import std.algorithm: min, max, clamp;

	struct Plot
	{
		size_t width, height;

		this(R _data, size_t _width, size_t _height, const(PlotParams) _params)
		{
			data = _data;
			width = _width;
			height = _height;
			params = _params;

			import std.math: isNaN, abs;
			import std.algorithm: reduce;
			if(params.min.isNaN)
				params.min = data.reduce!((a, b) => min(a, b));
			if(params.max.isNaN)
				params.max = data.reduce!((a, b) => max(a, b));

			samplesPerPixel = cast(double)(data.length-1) / cast(double)(width-1);
			pixelsPerSample = 1 / samplesPerPixel;
			rangePerPixel = cast(double)(params.max - params.min) / cast(double)(height-1);
			pixelsPerRange = 1 / rangePerPixel;
			halfLineW = params.width*0.5 + 0.25;
			halfLineWSq = halfLineW^^2;

			sampleThresholdX = halfLineW;
			sampleThresholdY = abs(halfLineW);
		}

		double opIndex(size_t x, size_t y)
		{
			if(data.length < 2)
			{
				if(data.length == 0)
					return 0;

				// TODO: draw a flat line...
				return 0;
			}

			double _x = cast(double)x;
			double _y = cast(double)y;

			// find the range the pixel could intersect with
			size_t first = cast(size_t)max((_x-sampleThresholdX)*samplesPerPixel, 0);
			size_t last = min(cast(size_t)((_x+sampleThresholdX)*samplesPerPixel + 2), data.length);

			// early-exit if we are not near the graph
			// TODO: should be easy to detect an early out

			// find nearest line segment
			double d = halfLineWSq;
			foreach(i; first+1 .. last)
			{
				double sx = (i-1)*pixelsPerSample;
				double sy = (params.max-data[i-1])*pixelsPerRange;
				double vx = pixelsPerSample;
				double vy = (params.max-data[i])*pixelsPerRange-sy;

				double t = clamp((vx*(_x-sx) + vy*(_y-sy)) / (vx*vx + vy*vy), 0.0, 1.0);

				double dx = _x-(sx+t*vx);
				double dy = _y-(sy+t*vy);

				d = min(dx*dx + dy*dy, d);
			}
			return d >= halfLineWSq ? 0 : min(halfLineW - d^^0.5, 1);
		}

	private:
		R data;
		PlotParams params;
		double samplesPerPixel, pixelsPerSample;
		double rangePerPixel, pixelsPerRange;
		double halfLineW, halfLineWSq;
		double sampleThresholdX, sampleThresholdY;
	}

	return Plot(data, width, height, params);
}

auto plotPoints(R)(R data, size_t width, size_t height, PlotParams params = PlotParams.init) if(isRandomAccessRange!R && is(ElementType!R : double))
{
	import std.algorithm: min, max, clamp;

	struct Plot
	{
		size_t width, height;

		this(R _data, size_t _width, size_t _height, const(PlotParams) _params)
		{
			data = _data;
			width = _width;
			height = _height;
			params = _params;

			import std.math: isNaN, abs;
			import std.algorithm: reduce;
			if(params.min.isNaN || params.max.isNaN)
			{
				params.min = data.reduce!((a, b) => min(a, b));
				params.max = data.reduce!((a, b) => max(a, b));
			}

			samplesPerPixel = cast(double)(data.length-1) / cast(double)(width-1);
			pixelsPerSample = 1 / samplesPerPixel;
			rangePerPixel = cast(double)(params.max - params.min) / cast(double)(height-1);
			pixelsPerRange = 1 / rangePerPixel;

			halfW = params.width*0.5 + 0.25;
			halfWSq = halfW^^2;

			sampleThresholdX = halfW;
		}

		double opIndex(size_t x, size_t y)
		{
			double _x = cast(double)x;
			double _y = cast(double)y;

			// find points that the pixel could touch
			size_t first = cast(size_t)max((_x-sampleThresholdX)*samplesPerPixel + 0.5, 0);
			size_t last = min(cast(size_t)((_x+sampleThresholdX)*samplesPerPixel + 1.5), data.length);

			// find nearest point
			double d = halfWSq;
			foreach(i; first .. last)
			{
				double sx = i*pixelsPerSample;
				double sy = (params.max-data[i])*pixelsPerRange;
				double dx = _x-sx;
				double dy = _y-sy;

				d = min(dx*dx + dy*dy, d);
			}
			return d >= halfWSq ? 0 : min(halfW - d^^0.5, 1);
		}

	private:
		R data;
		PlotParams params;
		double samplesPerPixel, pixelsPerSample;
		double rangePerPixel, pixelsPerRange;
		double halfW, halfWSq;
		double sampleThresholdX;
	}

	return Plot(data, width, height, params);
}


enum LineGraphFlags : uint
{
	Lines = 1<<0,
	Points = 1<<1,
	VerticalGuides = 1<<2,
	HorizontalGuides = 1<<3,
	VerticalTics = 1<<4,
	HorizontalTics = 1<<5,
	LeftEdge = 1<<6,
	BottomEdge = 1<<7,
	TopEdge = 1<<8,
	RightEdge = 1<<9
}

struct LineGraphParams
{
	double yMin, yMax;
	double xMin, xMax;

	double xTicFrequency;
	double yTicFrequency;

	float edgeWidth = 1;
	float hGuideWidth = 1;
	float vGuideWidth = 1;
	float ticWidth = 1;
	float ticLength = 1;

	float lineWidth = 1;
	float pointWidth = 3;

	RGB gbColor = RGB(255,255,255);
	RGB lineColor = RGB(0,0,0);
	RGB hGuideColor = RGB(224,224,224);
	RGB vGuideColor = RGB(224,224,224);
	RGB edgeColor = RGB(0,0,0);
	RGB ticColor = RGB(0,0,0);

	uint flags = LineGraphFlags.Lines;
}



alias lRGB = Color!("rgb", double, ColorSpace.sRGB_l);

auto plotWaveform(F)(F[] signal, size_t width, size_t height)
{
	static if(isFloatingPoint!F)
		auto s = signal;
	else static if(is(F == short))
		auto s = signal.map!(e => e*(1.0f/short.max));
	else static if(is(F == ubyte))
		auto s = signal.map!(e => e*(1.0f/ubyte.max)*2 - 1);

	PlotParams p;
	p.width = 1.5;
	p.min = -1; p.max = 1;
	return s
		.plot(width, height, p)
		.colorMap!(c => lRGB(1-c, 1, 1-c));
}

auto plotAmplitude(F)(F[] signal, size_t width, size_t height)
{
	import std.math: log10;

	static if(is(F == Complex!T, T))
		auto s = signal.map!(e => 20*log10(std.complex.abs(e)));
	else static if(isFloatingPoint!F)
		auto s = signal.map!(e => 20*log10(e));

	PlotParams p;
	p.width = 1.5;
	p.min = -120; p.max = 0;
	return s
		.plot(width, height, p)
		.colorMap!(c => lRGB(1, 1-c, 1-c));
}

auto plotPhase(F)(F[] signal, size_t width, size_t height)
{
	PlotParams p;
	p.width = 1.5;
	return signal.phase.dup
		.plot(width, height, p)
		.colorMap!(c => lRGB(1-c, 1-c, 1));
}

auto plotSpectrum(F)(F[][] signal)
{
	static spectrumColours = [
		lRGB(0,0,1),
		lRGB(0,1,1),
		lRGB(1,1,0),
		lRGB(1,0,0),
		lRGB(0,0,0)
	];

	return signal
		.matrixFrom2DArray
		.coordMap!((x, y, w, h) => tuple(x, cast(size_t)((double(y)/h)^^2.0*h)))
		.vFlip
		.colorMap!(e => lerpRange(clamp(toDecibels(e)/200 + 1, 0, 1), spectrumColours));
}
