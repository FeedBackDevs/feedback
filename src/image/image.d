module image.image;

public import std.experimental.color;
import std.typetuple: allSatisfy;
import std.typecons: tuple;

// This code was inspired by Vladimir Panteleev's excellent article:
// http://blog.thecybershadow.net/2014/03/21/functional-image-processing-in-d/

enum isImage(T) = is(typeof(T.init.width) : size_t) &&  // width
                  is(typeof(T.init.height) : size_t) && // height
                  is(typeof(T.init[0, 0]));             // color information

alias ImageColor(T) = typeof(T.init[0, 0]);

enum isWritableImage(T) = isImage!T && is(typeof(T.init[0, 0] = ImageColor!T.init));

enum isDirectImage(T) = isImage!T && is(typeof(T.init.scanline(0)) : ImageColor!T[]);


mixin template DirectView()
{
	alias Color = typeof(scanline(0)[0]);

	ref Color opIndex(size_t x, size_t y)
	{
		return scanline(y)[x];
	}

	Color opIndexAssign(Color value, size_t x, size_t y)
	{
		return scanline(y)[x] = value;
	}
}

struct Image(Color)
{
	size_t width, height;
	Color[] pixels;

	Color[] scanline(size_t y)
	{
		assert(y<height);
		return pixels[width*y .. width*(y+1)];
	}

	mixin DirectView;

	this(size_t width, size_t height)
	{
		size(width, height);
	}

	this(Color[] pixels, size_t width, size_t height)
	{
		assert(pixels.length == width*height);
		this.pixels = pixels;
		this.width = width;
		this.height = height;
	}

	void size(size_t width, size_t height)
	{
		this.width = width;
		this.height = height;
		if (pixels.length < width*height)
			pixels.length = width*height;
	}
}

template procedural(alias formula)
{
	alias Color = typeof(formula(0, 0));

	auto procedural(size_t width, size_t height)
	{
		struct Procedural
		{
			size_t width, height;

			auto ref Color opIndex(size_t x, size_t y)
			{
				return formula(x, y);
			}
		}
		return Procedural(width, height);
	}
}

auto solid(Color)(Color c, size_t width, size_t height)
{
	return procedural!((x, y) => c)(width, height);
}

auto blit(Src, Dest)(auto ref Src src, auto ref Dest dest) if(isImage!Src && isWritableImage!Dest)
{
	assert(src.width == dest.width && src.height == dest.height, "View size mismatch");
	foreach (y; 0 .. src.height)
	{
		static if(isDirectImage!Src && isDirectImage!Dest)
		{
			dest.scanline(y)[] = src.scanline(y)[];
		}
		else
		{
			foreach(x; 0 .. src.width)
				dest[x, y] = src[x, y];
		}
	}
	return dest;
}

auto clone(Dest, Src)(auto ref Src src) if (isImage!Src && isWritableImage!Dest)
{
	auto dest = Dest(src.width, src.height);
	return src.blit(dest);
}

template colorMap(alias pred)
{
	auto colorMap(Img)(auto ref Img src) if(isImage!Img)
	{
		alias SrcColor = ImageColor!Img;
		alias DestColor = typeof(pred(SrcColor.init));

		struct ColorMap
		{
			Img src;

			@property size_t width() { return src.width; }
			@property size_t height() { return src.height; }

			auto ref DestColor opIndex(size_t x, size_t y)
			{
				return pred(src[x, y]);
			}
		}

		return ColorMap(src);
	}
}

auto coordMap(alias pred, Img)(auto ref Img src) if(isImage!Img)
{
	struct CoordMap
	{
		Img src;

		@property size_t width() { return src.width; }
		@property size_t height() { return src.height; }

		auto ref opIndex(size_t x, size_t y)
		{
			return src[pred(x, y, width, height).expand];
		}
	}
	return CoordMap(src);
}

auto vFlip(Img)(auto ref Img src) if(isImage!Img)
{
	struct VFlip
	{
		Img src;

		@property size_t width() { return src.width; }
		@property size_t height() { return src.height; }

		auto ref opIndex(size_t x, size_t y)
		{
			return src[x, height-y-1];
		}
	}
	return VFlip(src);
}

auto vertical(Img...)(Img images) if(allSatisfy!(isImage, Img)) // TODO: prove the colours are the same...
{
	alias Color = ImageColor!(Img[0]);

	struct Vertical
	{
		Img images;
		size_t width, height;

		auto ref Color opIndex(size_t x, size_t y)
		{
			size_t v;
			foreach(i; images)
			{
				if(y < v + i.height)
				{
					if(x < i.width)
						return i[x, y-v];
					else
						break;
				}
				v += i.height;
			}
			return Color();
		}
	}
	size_t width, height;
	foreach(i; images)
	{
		width = i.width > width ? i.width : width;
		height += i.height;
	}
	return Vertical(images, width, height);
}

auto horizontal(Img...)(Img images) if(allSatisfy!(isImage, Img)) // TODO: prove the colours are the same...
{
	alias Color = ImageColor!(Img[0]);

	struct Horizontal
	{
		Img images;
		size_t width, height;

		auto ref Color opIndex(size_t x, size_t y)
		{
			size_t h;
			foreach(i; images)
			{
				if(x < h + i.width)
				{
					if(y < i.height)
						return i[x-h, y];
					else
						break;
				}
				h += i.width;
			}
			return Color();
		}
	}
	size_t width, height;
	foreach(i; images)
	{
		width += i.width;
		height = i.height > height ? i.height : height;
	}
	return Horizontal(images, width, height);
}



enum ImageFormat
{
	TGA
}

void save(Img)(Img img, const(char)[] filename, ImageFormat format = ImageFormat.TGA) if(isImage!Img)
{
	assert(format == ImageFormat.TGA);

	size_t w = img.width;
	size_t h = img.height;

	assert(w <= ushort.max && h <= ushort.max, "Image is too large!");

	ubyte[] buffer = new ubyte[TgaHeader.sizeof + img.width*img.height*RGB.sizeof];
	buffer[0..18] = 0;

	TgaHeader* header = cast(TgaHeader*)&buffer[0];
	header.imageType = 2;
	header.width = cast(ushort)w;
	header.height = cast(ushort)h;
	header.bpp = 24;
	header.flags = 0x20;

	BGR[] image = (cast(BGR*)&buffer[18])[0 .. w*h];
	size_t i = 0;
	foreach(y; 0..h)
	{
		foreach(x; 0..w)
			image[i++] = to!BGR(img[x, y]);
	}

	import std.file;
	write(filename, buffer);
}


private:

struct TgaHeader
{
	align(1):
	ubyte idLength;
	ubyte colourMapType;
	ubyte imageType;

	ushort colourMapStart;
	ushort colourMapLength;
	ubyte colourMapBits;

	ushort xStart;
	ushort yStart;
	ushort width;
	ushort height;
	ubyte bpp;
	ubyte flags;
}
