module db.tools.image.image;

public import image.image;

import fuji.texture;


private template GetAttribute(alias T, Attr)
{
	template Impl(T...)
	{
		static if (T.length == 0)
			enum Impl = Attr.Unknown;
		else
			enum Impl = is(typeof(T[0]) == Attr) ? T[0] : Impl!(T[1..$]);
	}

	enum GetAttribute = Impl!(__traits(getAttributes, T));
}


void create(Img)(Texture texture, ref const(Img) image, MFImageFormat format, const(char)[] name, bool generateMips = true) if (isImage!Img)
{
	alias Color = ImageColor!Img;

//	enum Format = GetAttribute!(Color, MFImageFormat);
//	static assert(Format != MFImageFormat.Unknown, Img.stringof ~ " has no MFImageFormat attribute.");

	static if (is(Img == Image!Color))
		alias buffer = image;
	else
		auto buffer = image.clone!(Image!Color)(src);

	auto n = Stringz!(64)(name);

	texture.release();
	texture.pTexture = MFTexture_CreateFromRawData(n, buffer.pixels.ptr, cast(int)image.width, cast(int)image.height, format, TextureFlags.CopyMemory, generateMips);
}

Texture createTexture(Img)(ref const(Img) image, MFImageFormat format, const(char)[] name, uint flags = MFTextureCreateFlags.GenerateMips) if (isImage!Img)
{
	alias Color = ImageColor!Img;

	static if (is(Img == Image!Color))
		alias buffer = image;
	else
		auto buffer = image.clone!(Image!Color)(src);

	auto n = Stringz!(64)(name);

	Texture t;
	t.pTexture = MFTexture_CreateFromRawData(n, buffer.pixels.ptr, cast(int)image.width, cast(int)image.height, format, flags);
	return t;
}

bool updateTexture(Img)(Img image, ref Texture tex) if (isImage!Img)
{
	alias Color = ImageColor!Img;

	assert(tex.width == image.width && tex.height == image.height, "Image has incorrect dimensions");

	static if (is(Img == Image!Color))
	{
		// if the image is a buffered image of the appropriate format, we can pass the pointer
		return MFTexture_Update(tex.pTexture, 0, 0, image.pixels.ptr);
	}
	else
	{
		// we need to copy into the buffer
		MFLockedTexture l;
		if (MFTexture_Map(tex.pTexture, 0, 0, &l))
		{
			auto pixels = (cast(ImageColor!Img*)l.pData)[0..l.width*l.height];
			auto target = Image!(ImageColor!Img)(pixels, l.width, l.height);
			image.blit(target);
			MFTexture_Unmap(tex.pTexture, 0, 0);
			return true;
		}
		return false;
	}
}
