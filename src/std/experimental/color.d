module std.experimental.color;

import std.traits: isFloatingPoint, isIntegral, isSigned, isSomeChar, Unqual;
import std.algorithm: canFind;
import std.typetuple;
import std.typecons;

// I'd like to put this down the bottom with the other private stuff but...
// *** std.algorithm is not @nogc or nothrow >_<
// also, we can't un-pure/nothrow/@nogc/@safe
private
{
    import std.range: isInputRange, ElementType;

    bool allIn(Range)(Range things, Range range) if (isInputRange!Range)
    {
        foreach(thing; things)
            if(!range.canFind(thing))
                return false;
        return true;
    }
    bool anyIn(Range)(Range things, Range range) if (isInputRange!Range)
    {
        foreach(thing; things)
            if(range.canFind(thing))
                return true;
        return false;
    }
    ElementType!Range notIn(Range)(Range things, Range range) if (isInputRange!Range)
    {
        foreach(thing; things)
            if(!range.canFind(thing))
                return thing;
        return true;
    }
}

@safe: pure: nothrow: @nogc:

// defined color spaces, more to come!
enum ColorSpace
{
    XYZ,        // CIE 1931
//    UVW,        // CIE 1964
    xyY,        // CIE xyY
    Lab,        // CIA Lab

    sRGB,       // sRGB
    sRGB_gamma, // Gamma 2.2 sRGB
    sRGB_l,     // Linear sRGB
    AdobeRGB,   // Adobe RGB
    AdobeRGB_l, // Linear Adobe RGB

//    YUV,        // There are multiple YUV spaces...

//    HSV,        // HSV and HSL?

//    CMYK        // Maybe not; CMYK depends on OS color profiles from printer drivers and stuff...
}

enum WhitePoint
{
    A =   [ 1.09850, 1.00000, 0.35585 ],
    B =   [ 0.99072, 1.00000, 0.85223 ],
    C =   [ 0.98074, 1.00000, 1.18232 ],
    D50 = [ 0.96422, 1.00000, 0.82521 ],
    D55 = [ 0.95682, 1.00000, 0.92149 ],
    D65 = [ 0.95047, 1.00000, 1.08883 ],
    D75 = [ 0.94972, 1.00000, 1.22638 ],
    E =   [ 1.00000, 1.00000, 1.00000 ],
    F2 =  [ 0.99186, 1.00000, 0.67393 ],
    F7 =  [ 0.95041, 1.00000, 1.08747 ],
    F11 = [ 1.00962, 1.00000, 0.64350 ]
}

enum isColor(T) = is(T == Color!(cmp, CT, cs), string cmp, CT, ColorSpace cs);
enum isRGB(ColorSpace c) = c == ColorSpace.sRGB || c == ColorSpace.sRGB_gamma || c == ColorSpace.sRGB_l || c == ColorSpace.AdobeRGB || c == ColorSpace.AdobeRGB_l;

struct Color(string components_, ComponentType_, ColorSpace colorSpace_ = ColorSpace.sRGB) if(isValidComponentType!ComponentType_)
{
    // mixin to fabricate component members
    private static string declComponents()
    {
        string s;
        foreach(i, c; components)
            s ~= (c == 'x' ? "private " : "") ~ ComponentType.stringof ~ ' ' ~ c ~ ";\n";
        return s;
    }
    mixin(declComponents());

@safe: pure: nothrow: @nogc:

    alias ComponentType = ComponentType_;
    enum string components = components_;
    enum ColorSpace colorSpace = colorSpace_;

    // various useful introspection
    enum bool hasAlpha = components.canFind('a');

    // each color space has a slightly different constructor and some contractual requirements
    static if(colorSpace == ColorSpace.XYZ)
    {
        static assert(components.allIn("xyza"), "Invalid Color component '"d ~ components.notIn("xyza") ~ "'. XYZ colors may only contain components: x, y, z, a"d);
        static assert(components.canFind('x') && components.canFind('y') && components.canFind('z'), "XYZ colors must have all components: x, y, z"d);

        auto tristimulus() const { return tuple(x, y, z); }

        // CIE XYZ constructor
        this(ComponentType x, ComponentType y, ComponentType z, ComponentType a = 0)
        {
            this.x = x;
            this.y = y;
            this.z = z;
            static if(components.canFind('a'))
                this.a = a;
        }
    }
    static if(isRGB!colorSpace)
    {
        // RGB colors may only contain components 'rgb', or 'l' (luminance)
        // They may also optionally contain an 'a' (alpha) component, and 'x' (unused) components

        // Missing components will be fabricated to produce appropriate values

        static assert(components.allIn("rgblax"), "Invalid Color component '"d ~ components.notIn("rgblax") ~ "'. RGB colors may only contain components: r, g, b, l, a, x"d);
        static assert(components.anyIn("rgbal"), "RGB colors must contain at least one component of r, g, b, l, a.");
        static assert(!components.canFind('l') || !components.anyIn("rgb"), "RGB colors may not contain rgb AND luminance components together.");

        // missing components will be available, default to 0
        static if(!components.canFind('r'))
        {
            static if(!components.canFind('l'))
                enum ComponentType r = 0;
            else
                alias r = l;
        }
        static if(!components.canFind('g'))
        {
            static if(!components.canFind('l'))
                enum ComponentType g = 0;
            else
                alias g = l;
        }
        static if(!components.canFind('b'))
        {
            static if(!components.canFind('l'))
                enum ComponentType b = 0;
            else
                alias b = l;
        }
        static if(!components.canFind('l'))
            @property ComponentType l() const nothrow @nogc { return toGrayscale!colorSpace(r, g, b); }
        static if(!components.canFind('a'))
            enum ComponentType a = 1;

        static if(components.canFind('l'))
            auto tristimulus() const { auto t = l; return tuple(t, t, t); }
        else
            auto tristimulus() const { return tuple(r, g, b); }

        static if(hasAlpha)
            auto tristimulusWithAlpha() const { return tuple(tristimulus.expand, a); }
        else
            auto tristimulusWithAlpha() const { return tuple(tristimulus.expand, ComponentType(1)); }

        // RGB/A initialiser
        this(ComponentType r, ComponentType g, ComponentType b, ComponentType a = 1)
        {
            static if(components.canFind('r'))
                this.r = r;
            static if(components.canFind('g'))
                this.g = g;
            static if(components.canFind('b'))
                this.b = b;
            static if(components.canFind('a'))
                this.a = a;
            static if(components.canFind('l'))
                this.l = toGrayscale!colorSpace(r, g, b);
        }

        // L/A initialiser
        this(ComponentType l, ComponentType a = 1)
        {
            static if(components.canFind('l'))
                this.l = l;
            static if(components.canFind('r'))
                this.r = l;
            static if(components.canFind('g'))
                this.g = l;
            static if(components.canFind('b'))
                this.b = l;
            static if(components.canFind('a'))
                this.a = a;
        }

        // Hex string initialiser
        this(C)(const(C)[] hex) if(isSomeChar!C)
        {
            fromHex(hex);
        }

        // read hex strings in the standard forms: (#/$/0x)rgb/argb/rrggbb/aarrggbb
        void fromHex(S)(const(S)[] hex) if(isSomeChar!S)
        {
            static ubyte val(S c)
            {
                if(c >= 0 && c <= 9)
                    return c - '0';
                else if(c >= 'a' && c <= 'f')
                    return c - 'a' + 10;
                else if(c >= 'A' && c <= 'F')
                    return c - 'A' + 10;
                else
                    assert(false, "Invalid hex string");
            }

            if(hex[0] == '#' || hex[0] == '$')
                hex = hex[1..$];
            else if(hex[0] == '0' && hex[1] == 'x')
                hex = hex[2..$];

            if(hex.length == 3)
            {
                ubyte r = val(hex[0]);
                ubyte g = val(hex[1]);
                ubyte b = val(hex[2]);
                this = Color!("rgb", ubyte, colorSpace)(r | (r << 4), g | (g << 4), b | (b << 4));
            }
            if(hex.length == 4)
            {
                ubyte a = val(hex[0]);
                ubyte r = val(hex[1]);
                ubyte g = val(hex[2]);
                ubyte b = val(hex[3]);
                this = Color!("rgba", ubyte, colorSpace)(r | (r << 4), g | (g << 4), b | (b << 4), a | (a << 4));
            }
            if(hex.length == 6)
            {
                ubyte r = (val(hex[0]) << 4) | val(hex[1]);
                ubyte g = (val(hex[2]) << 4) | val(hex[3]);
                ubyte b = (val(hex[4]) << 4) | val(hex[5]);
                this = Color!("rgb", ubyte, colorSpace)(r, g, b);
            }
            if(hex.length == 8)
            {
                ubyte a = (val(hex[0]) << 4) | val(hex[1]);
                ubyte r = (val(hex[2]) << 4) | val(hex[3]);
                ubyte g = (val(hex[4]) << 4) | val(hex[5]);
                ubyte b = (val(hex[6]) << 4) | val(hex[7]);
                this = Color!("rgba", ubyte, colorSpace)(r, g, b, a);
            }
            else
                assert(false, "Invalid hex string!");
        }
    }

    C opCast(C)() if(isColor!C)
    {
        return this.to!C;
    }

    typeof(this) opUnary(string op)() const pure nothrow @nogc
    {
        Unqual!(typeof(this)) r = this;
        static if(components.canFind('l'))
            mixin("r.l = "~op~"l;");
        static if(components.canFind('r'))
            mixin("r.r = "~op~"r;");
        static if(components.canFind('g'))
            mixin("r.g = "~op~"g;");
        static if(components.canFind('b'))
            mixin("r.b = "~op~"b;");
        static if(components.canFind('a'))
            mixin("r.a = "~op~"a;");
        return r;
    }

    typeof(this) opBinary(string op, C)(C rh) const pure nothrow @nogc if(isColor!C && (op == "+" || op == "-" || op == "*" || op == "/"))
    {
        Unqual!(typeof(this)) r = this;
        auto arg = cast(typeof(this))rh;
        static if(components.canFind('l'))
            mixin("r.l "~op~"= arg.l;");
        static if(components.canFind('r'))
            mixin("r.r "~op~"= arg.r;");
        static if(components.canFind('g'))
            mixin("r.g "~op~"= arg.g;");
        static if(components.canFind('b'))
            mixin("r.b "~op~"= arg.b;");
        static if(components.canFind('a'))
            mixin("r.a "~op~"= arg.a;");
        return r;
    }

    typeof(this) opBinary(string op, F)(F rh) const pure nothrow @nogc if(isFloatingPoint!F && (op == "*" || op == "/" || op == "^^"))
    {
        Unqual!(typeof(this)) r = this;
        static if(components.canFind('l'))
            mixin("r.l "~op~"= rh;");
        static if(components.canFind('r'))
            mixin("r.r "~op~"= rh;");
        static if(components.canFind('g'))
            mixin("r.g "~op~"= rh;");
        static if(components.canFind('b'))
            mixin("r.b "~op~"= rh;");
        static if(components.canFind('a'))
            mixin("r.a "~op~"= rh;");
        return r;
    }

    typeof(this) opBinaryRight(string op, F)(F rh) const pure nothrow @nogc if(isFloatingPoint!F && (op == "*" || op == "/"))
    {
        Unqual!(typeof(this)) r = this;
        static if(components.canFind('l'))
            mixin("r.l "~op~"= rh;");
        static if(components.canFind('r'))
            mixin("r.r "~op~"= rh;");
        static if(components.canFind('g'))
            mixin("r.g "~op~"= rh;");
        static if(components.canFind('b'))
            mixin("r.b "~op~"= rh;");
        static if(components.canFind('a'))
            mixin("r.a "~op~"= rh;");
        return r;
    }

    ref typeof(this) opOpAssign(string op, C)(C rh) pure nothrow @nogc if(isColor!C && (op == "+" || op == "-" || op == "*" || op == "/"))
    {
        auto arg = cast(typeof(this))rh;
        static if(components.canFind('l'))
            mixin("l "~op~"= arg.l;");
        static if(components.canFind('r'))
            mixin("r "~op~"= arg.r;");
        static if(components.canFind('g'))
            mixin("g "~op~"= arg.g;");
        static if(components.canFind('b'))
            mixin("b "~op~"= arg.b;");
        static if(components.canFind('a'))
            mixin("a "~op~"= arg.a;");
        return this;
    }

    ref typeof(this) opOpAssign(string op, F)(F rh) pure nothrow @nogc if(isFloatingPoint!F && (op == "*" || op == "/" || op == "^^"))
    {
        static if(components.canFind('l'))
            mixin("l "~op~"= rh;");
        static if(components.canFind('r'))
            mixin("r "~op~"= rh;");
        static if(components.canFind('g'))
            mixin("g "~op~"= rh;");
        static if(components.canFind('b'))
            mixin("b "~op~"= rh;");
        static if(components.canFind('a'))
            mixin("a "~op~"= rh;");
        return this;
    }
}




// declare some common color types...

alias RGB =    Color!("rgb", ubyte);
alias RGBX =   Color!("rgbx", ubyte);
alias RGBA =   Color!("rgba", ubyte);

alias BGR =    Color!("bgr", ubyte);
alias BGRX =   Color!("bgrx", ubyte);
alias BGRA =   Color!("bgra", ubyte);

alias RGB16 =  Color!("rgb", ushort);
alias RGBX16 = Color!("rgbx", ushort);
alias RGBA16 = Color!("rgba", ushort);

alias L8 =     Color!("l", ubyte);
alias L16 =    Color!("l", ushort);
alias LA =     Color!("la", ubyte);
alias LA16 =   Color!("la", ushort);

alias UV8 =    Color!("rg", byte);

alias XYZ =    Color!("xyz", float, ColorSpace.XYZ);


// TODO: represent packed colors, eg R5G6B5, etc
struct PackedColor(string format, ColorSpace colorSpace = ColorSpace.sRGB)
{
    // TODO: we'll try and fabricate the packing algorithm based on the format string
    //...

    void pack(C)(C color);
    C unpack(C)();
}

// std.conv style to! function, which performs almost all conversion operations
To to(To, From)(From color) if(isColor!To && isColor!From)
{
    alias ToType = To.ComponentType;
    alias FromType = From.ComponentType;

    auto src = color.tristimulusWithAlpha;

    static if(From.colorSpace == To.colorSpace)
    {
        // color space is the same, just do type conversion
        return To(convert!ToType(src[0]), convert!ToType(src[1]), convert!ToType(src[2]), convert!ToType(src[3]));
    }
    else
    {
        static if(false && FromType.sizeof <= 2 && ToType.sizeof <= 2)
        {
            // <= 16bit type conversion should use a look-up table

            // TODO: this is blocked by '^^' not working in CTFE!
        }
        else
        {
            // full color space conversion

            // unpack the working values
            alias WorkType = WorkingType!(FromType, ToType);
            WorkType a = convert!WorkType(src[0]);
            WorkType b = convert!WorkType(src[1]);
            WorkType c = convert!WorkType(src[2]);

            // perform the color space conversion
            auto r = convertColorSpace!(From.colorSpace, To.colorSpace)(a, b, c);

            // convert and return the output
            return To(convert!ToType(a), convert!ToType(b), convert!ToType(c), convert!ToType(src[3]));
        }
    }
}

C blend(C, F)(C src, C dest, F destFactor)
{
    return blend(src, dest, 1-destFactor, destFactor, 1-destFactor, destFactor);
}

C blend(C, F)(C src, C dest, F srcFactor, F destFactor)
{
    return blend(src, dest, srcFactor, destFactor, srcFactor, destFactor);
}

C blend(C, F)(C src, C dest, F srcFactor, F destFactor, F srcAlphaFactor, F destAlphaFactor) if(isColor!C && isFloatingPoint!F)
{
    C r;
    static if(C.components.canFind('r'))
        r.r = cast(typeof(r.r))(src.r*srcFactor + dest.r*destFactor);
    static if(C.components.canFind('g'))
        r.g = cast(typeof(r.g))(src.g*srcFactor + dest.g*destFactor);
    static if(C.components.canFind('b'))
        r.b = cast(typeof(r.b))(src.b*srcFactor + dest.b*destFactor);
    static if(C.components.canFind('l'))
        r.l = cast(typeof(r.l))(src.l*srcFactor + dest.l*destFactor);
    static if(C.components.canFind('a'))
        r.a = cast(typeof(r.a))(src.a*srcAlphaFactor + dest.a*destAlphaFactor);
    return r;
}


// helper functions

// **BLOCKER**: these functions can't CTFE ('^^' doesnt work), which means I can't generate conversion tables! >_<

T sRGBToLinear(T)(T s) pure if(isFloatingPoint!T)
{
    if(s <= T(0.04045))
        return s / T(12.92);
    else
        return ((s + T(0.055)) / T(1.055))^^T(2.4);
}
T gammaToLinear(T)(T s) pure if(isFloatingPoint!T)
{
    return s^^T(2.2);
}
T adobeToLinear(T)(T s) pure if(isFloatingPoint!T)
{
    return s^^T(2.19921875);
}

T linearTosRGB(T)(T s) pure if(isFloatingPoint!T)
{
    if(s <= T(0.0031308))
        return T(12.92) * s;
    else
        return T(1.055) * s^^T(1.0/2.4) - T(0.055);
}
T linearToGamma(T)(T s) pure if(isFloatingPoint!T)
{
    return s^^T(1.0/2.2);
}
T linearToAdobe(T)(T s) pure if(isFloatingPoint!T)
{
    return s^^T(1.0/2.19921875);
}

T toGrayscale(ColorSpace colorSpace = ColorSpace.sRGB, T)(T r, T g, T b) pure if(isFloatingPoint!T)
{
/*
    TODO: do i have this function right? am i in the wrong space?

    // i think this is the linear conversion coefficients
    wiki = 0.299r + 0.587g + 0.114b
    ps: (0.3)+(0.59)+(0.11)

    // but gimp source seems to use this one... perhaps this performs an sRGB space estimate, or is THIS the linear one?
    gimp: 0.21 R + 0.72 G + 0.07 B
    another = 0.2126 R + 0.7152 G + 0.0722 B   (apparently in linear space?)
*/
    static if(colorSpace == ColorSpace.sRGB_l)
        return T(0.299)*r + T(0.587)*g + T(0.114)*b;
    else static if(colorSpace == ColorSpace.sRGB_gamma)
        return linearToGamma(T(0.299)*gammaToLinear(r) + T(0.587)*gammaToLinear(g) + T(0.114)*gammaToLinear(b));
    else static if(colorSpace == ColorSpace.sRGB)
        return linearTosRGB(T(0.299)*sRGBToLinear(r) + T(0.587)*sRGBToLinear(g) + T(0.114)*sRGBToLinear(b));
}

Tuple!(T, T, T) convertColorSpace(ColorSpace from, ColorSpace to, T)(T a, T b, T c) pure if(isFloatingPoint!T)
{
    static if(from == to)
        return tuple(a,b,c);
    else static if(isRGB!from && isRGB!to)
        return RGB_to_RGB!(from, to)(a, b, c);
    else static if(from == isRGB!from)
    {
        static if(0)//to == ColorSpace.HSV)
            0;
        else static if(0)//to == ColorSpace.YUV)
            0;
        else
            return convertColorSpace!(ColorSpace.XYZ, to)(RGB_to_XYZ!from(a, b, c).unpack);
    }
    else static if(from == ColorSpace.Lab)
        return convertColorSpace!(ColorSpace.XYZ, to)(Lab_to_XYZ(a, b, c).unpack);
    else static if(from == ColorSpace.xyY)
        return convertColorSpace!(ColorSpace.XYZ, to)(xyY_to_XYZ(a, b, c).unpack);
    else static if(from == ColorSpace.XYZ)
    {
        static if(isRGB!to)
            return XYZ_to_RGB!to(a,b,c); // pass through to HSV/YUV conversion...
        else static if(to == ColorSpace.Lab)
            return XYZ_to_Lab(a,b,c);
        else static if(to == ColorSpace.xyY)
            return XYZ_to_xyY(a,b,c);
    }
    else
        static assert(false, "Shouldn't be here! from: " ~ from.stringof ~ ", to: " ~ to.stringof);
}


// integer helpers

T toGrayscale(ColorSpace colorSpace = ColorSpace.sRGB, T)(T r, T g, T b) pure if(isIntegral!T)
{
    alias F = FloatTypeFor!T;
    return convert!T(toGrayscale!colorSpace(convert!F(r), convert!F(g), convert!F(b)));
}


private:

enum isValidComponentType(T) = isIntegral!T || isFloatingPoint!T;

// try and use the preferred float type, but if the int type exceeds the preferred float precision, we'll upgrade the float
template FloatTypeFor(IntType, RequestedFloat = float)
{
    static if(IntType.sizeof > 2)
        alias FloatTypeFor = double;
    else
        alias FloatTypeFor = RequestedFloat;
}

// find the fastest type to do format conversion without losing precision
template WorkingType(From, To)
{
    static if(isIntegral!From && isIntegral!To)
    {
        // small integer types can use float and not lose precision
        static if(From.sizeof < 4 && To.sizeof < 4)
            alias WorkingType = float;
        else
            alias WorkingType = double;
    }
    else static if(isIntegral!From && isFloatingPoint!To)
        alias WorkingType = To;
    else static if(isFloatingPoint!From && isIntegral!To)
        alias WorkingType = From;
    else
    {
        static if(From.sizeof > To.sizeof)
            alias WorkingType = From;
        else
            alias WorkingType = To;
    }
}

// convert between pixel data types
To convert(To, From)(From v) if(isValidComponentType!From && isValidComponentType!To)
{
    import std.algorithm: max;

    static if(isIntegral!From && isIntegral!To)
        return convertNormInt!To(v);
    else static if(isIntegral!From && isFloatingPoint!To)
    {
        static if(isSigned!From) // max(c, -1) is the signed conversion followed by D3D, OpenGL, etc.
            return To(max(v*FloatTypeFor!(From, To)(1.0/From.max), FloatTypeFor!(From, To)(-1.0)));
        else
            return To(v*FloatTypeFor!(From, To)(1.0/From.max));
    }
    else static if(isFloatingPoint!From && isIntegral!To)
        // TODO: actually, this is broken!
        //       + 0.5 only works for positive numbers, and we also need to clamp (saturate) [To.min, To.max]
        return cast(To)(v*FloatTypeFor!(To, From)(To.max) + FloatTypeFor!(To, From)(0.5));
    else
        return To(v);
}

// tuple for toLinear conversion functions
alias linearConversion(ColorSpace cs) = TypeTuple!(
    void,
    //void,
    void,
    void,
    sRGBToLinear,
    gammaToLinear,
    void,
    adobeToLinear,
    void,
    //void,
    //void,
    //void,
    //void
)[cs];

// tuple of toGamma conversion functions
alias gammaConversion(ColorSpace cs) = TypeTuple!(
    void,
    //void,
    void,
    void,
    sRGBToLinear,
    gammaToLinear,
    void,
    adobeToLinear,
    void,
    //void,
    //void,
    //void,
    //void
)[cs];

Tuple!(T, T, T) XYZ_to_xyY(T)(T X, T Y, T Z) pure if(isFloatingPoint!T)
{
    return tuple(X / (X+Y+Z), Y / (X+Y+Z), Y);
}

Tuple!(T, T, T) xyY_to_XYZ(T)(T x, T y, T Y) pure if(isFloatingPoint!T)
{
    return tuple(Y/y * x, Y, Y/y * (1 - x - y));
}

Tuple!(T, T, T) XYZ_to_Lab(T)(T X, T Y, T Z, ref W[3]) pure if(isFloatingPoint!T)
{
    static T f(T t)
    {
        return t > T((6.0/29.0)^^3.0) ? t^^T(1.0/3.0) : T((1.0/3.0)*(29.0/6.0)^^2.0)*t + T(4.0/29.0);
    }
    T L = T(116)*f(Y/W[1]) - T(16);
    T a = T(500)*(f(X/W[0]) - f(Y/W[1]));
    T b = T(200)*(f(Y/W[1]) - f(Z/W[2]));
    return tuple(L, a, b);
}

Tuple!(T, T, T) Lab_to_XYZ(T)(T L, T a, T b, ref W[3]) pure if(isFloatingPoint!T)
{
    static T f(T t)
    {
        return t > T(6.0/29.0) ? t^^T(3) : T(3.0*(6.0/29.0)^^2.0)*(t - T(4.0/29.0));
    }
    T X = W[0]*f(T(1.0/116.0)*(L + T(16)) + T(1.0/500.0)*a);
    T Y = W[1]*f(T(1.0/116.0)*(L + T(16)));
    T Z = W[2]*f(T(1.0/116.0)*(L + T(16)) - T(1.0/200.0)*b);
    return tuple(X, Y, Z);
}

Tuple!(T, T, T) XYZ_to_RGB(ColorSpace cs, T)(T X, T Y, T Z) pure if(isFloatingPoint!T)
{
    // transform color space
    alias t = fromXYZ!cs;
    T r = t[0]*X + t[1]*Y + t[2]*Z;
    T g = t[3]*X + t[4]*Y + t[5]*Z;
    T b = t[6]*X + t[7]*Y + t[8]*Z;

    // TODO: AdobeRGB->XYZ needs de-normalisation (expansion)

    // make non-linear
    static if(!is(gammaConversion!cs == void))
    {
        a = gammaConversion!to(a);
        b = gammaConversion!to(b);
        c = gammaConversion!to(c);
    }

    return tuple(a, b, c);
}

Tuple!(T, T, T) RGB_to_XYZ(ColorSpace cs, T)(T r, T g, T b) pure if(isFloatingPoint!T)
{
    // make linear
    static if(!is(linearConversion!cs == void))
    {
        r = linearConversion!from(r);
        g = linearConversion!from(g);
        b = linearConversion!from(b);
    }

    static if(0)
    {
        // TODO: XYZ->AdobeRGB needs normalisation
        // need to prove that this is actually correct!
        enum white = [ 152.07, 160.00, 174.25 ];
        enum black = [ 0.5282, 0.5557, 0.6052 ];

        r = (r - black[0]) / (white[0] - black[0]) * (white[0] / white[1]);
        g = (g - black[1]) / (white[1] - black[1]);
        b = (b - black[2]) / (white[2] - black[2]) * (white[2] / white[1]);
    }

    // transform color space
    alias t = toXYZ!cs;
    T X = t[0]*r + t[1]*g + t[2]*b;
    T Y = t[3]*r + t[4]*g + t[5]*b;
    T Z = t[6]*r + t[7]*g + t[8]*b;

    return tuple(X, Y, Z);
}

Tuple!(T, T, T) RGB_to_RGB(ColorSpace from, ColorSpace to, T)(T r, T g, T b) pure if(isFloatingPoint!T)
{
    // make linear
    static if(!is(linearConversion!from == void))
    {
        r = linearConversion!from(r);
        g = linearConversion!from(g);
        b = linearConversion!from(b);
    }

    static if(0)
    {
        // TODO: XYZ->AdobeRGB needs normalisation
        // need to prove that this is actually correct!
        enum white = [ 152.07, 160.00, 174.25 ];
        enum black = [ 0.5282, 0.5557, 0.6052 ];

        r = (r - black[0]) / (white[0] - black[0]) * (white[0] / white[1]);
        g = (g - black[1]) / (white[1] - black[1]);
        b = (b - black[2]) / (white[2] - black[2]) * (white[2] / white[1]);
    }

    // transform color space
    static if(needsTransform!(from, to))
    {
        alias t = transform!(toXYZ!from, fromXYZ!to);
        T tr = t[0]*r + t[1]*g + t[2]*b;
        T tg = t[3]*r + t[4]*g + t[5]*b;
        T tb = t[6]*r + t[7]*g + t[8]*b;
        r = tr; g = tg; b = tb;
    }

    // TODO: AdobeRGB->XYZ needs de-normalisation (expansion)

    // make non-linear
    static if(!is(gammaConversion!to == void))
    {
        r = gammaConversion!to(r);
        g = gammaConversion!to(g);
        b = gammaConversion!to(b);
    }

    return tuple(r, g, b);
}

enum float[9] identity = [ 1.0, 0.0, 0.0,
                           0.0, 1.0, 0.0,
                           0.0, 0.0, 1.0 ];

enum float[9] xyzTosRGB = [ 3.2404542, -1.5371385, -0.4985314,
                           -0.9692660,  1.8760108,  0.0415560,
                            0.0556434, -0.2040259,  1.0572252 ];

enum float[9] sRGBToXYZ = [ 0.4124564, 0.3575761, 0.1804375,
                            0.2126729, 0.7151522, 0.0721750,
                            0.0193339, 0.1191920, 0.9503041];

enum float[9] xyzToAdobe = [ 2.0413690, -0.5649464, -0.3446944,
                            -0.9692660,  1.8760108,  0.0415560,
                             0.0134474, -0.1183897,  1.0154096 ];

enum float[9] adobeToXYZ = [ 0.5767309, 0.1855540, 0.1881852,
                             0.2973769, 0.6273491, 0.0752741,
                             0.0270343, 0.0706872, 0.9911085 ];

enum float[9] transform(alias m, alias n) = [ m[0]*n[0]+m[3]*n[1]+m[6]*n[2], m[1]*n[0]+m[4]*n[1]+m[7]*n[2], m[2]*n[0]+m[5]*n[1]+m[8]*n[2],
                                              m[0]*n[3]+m[3]*n[4]+m[6]*n[5], m[1]*n[3]+m[4]*n[4]+m[7]*n[5], m[2]*n[3]+m[5]*n[4]+m[8]*n[5],
                                              m[0]*n[6]+m[3]*n[7]+m[6]*n[8], m[1]*n[6]+m[4]*n[7]+m[7]*n[8], m[2]*n[6]+m[5]*n[7]+m[8]*n[8] ];

alias toXYZ(ColorSpace cs) = TypeTuple!(
    identity,
    //identity,
    identity,
    identity,
    sRGBToXYZ,
    sRGBToXYZ,
    sRGBToXYZ,
    adobeToXYZ,
    adobeToXYZ,
    //identity,
    //identity,
    //identity,
    //identity
)[cs];

alias fromXYZ(ColorSpace cs) = TypeTuple!(
    identity,
    //identity,
    identity,
    identity,
    xyzTosRGB,
    xyzTosRGB,
    xyzTosRGB,
    xyzToAdobe,
    xyzToAdobe,
    //identity,
    //identity,
    //identity,
    //identity
)[cs];

enum needsTransform(ColorSpace from, ColorSpace to) = toXYZ!from != toXYZ!to;

// -- this is a painstaking function! i couldn't make it meta in any reasonable way! :( --
// converts directly between fixed-point color types, without doing float conversions
// ** this should be tested for performance; some of these might be slower than using imul/idiv, or even float
To convertNormInt(To, From)(From i)
{
    import std.traits: Unqual;
    alias F = Unqual!From;
    alias T = Unqual!To;

    static if(is(F == T))
        return i;

    // unsigned interchange
    else static if(is(F == ubyte) && is(T == ushort))
        return (ushort(i) << 8) | i;
    else static if(is(F == ubyte) && is(T == uint))
        return (uint(i) << 24) | (uint(i) << 16) | (uint(i) << 8) | i;
    else static if(is(F == ubyte) && is(T == ulong))
        return (ulong(i) << 56) | (ulong(i) << 48) | (ulong(i) << 40) | (ulong(i) << 32) | (ulong(i) << 24) | (ulong(i) << 16) | (ulong(i) << 8) | i;

    else static if(is(F == ushort) && is(T == ubyte))
        return ubyte(i >> 8);
    else static if(is(F == ushort) && is(T == uint))
        return (uint(i) << 16) | i;
    else static if(is(F == ushort) && is(T == ulong))
        return (ulong(i) << 48) | (ulong(i) << 32) | (ulong(i) << 16) | i;

    else static if(is(F == uint) && is(T == ubyte))
        return ubyte(i >> 24);
    else static if(is(F == uint) && is(T == ushort))
        return ushort(i >> 16);
    else static if(is(F == uint) && is(T == ulong))
        return (ulong(i) << 32) | i;

    else static if(is(F == ulong) && is(T == ubyte))
        return ubyte(i >> 56);
    else static if(is(F == ulong) && is(T == ushort))
        return ushort(i >> 48);
    else static if(is(F == ulong) && is(T == uint))
        return uint(i >> 32);

    // signed interchange
    else static if(is(F == byte) && is(T == short))
        return (short(i) << 8) | ((ushort(i)&byte.max) << 1) | ((ushort(i)&byte.max) >> 6);
    else static if(is(F == byte) && is(T == int))
        return (int(i) << 24) | ((uint(i)&byte.max) << 17) | ((uint(i)&byte.max) << 10) | ((uint(i)&byte.max) << 3) | ((uint(i)&byte.max) >> 4);
    else static if(is(F == byte) && is(T == long))
        return (long(i) << 56) | ((ulong(i)&byte.max) << 49) | ((ulong(i)&byte.max) << 42) | ((ulong(i)&byte.max) << 35) | ((ulong(i)&byte.max) << 28) | ((ulong(i)&byte.max) << 21) | ((ulong(i)&byte.max) << 14) | ((ulong(i)&byte.max) << 7) | (ulong(i)&byte.max);

    else static if(is(F == short) && is(T == byte))
        return byte(i >> 8);
    else static if(is(F == short) && is(T == int))
        return (int(i) << 16) | ((uint(i)&short.max) << 1) | ((uint(i)&short.max) >> 14);
    else static if(is(F == short) && is(T == long))
        return (long(i) << 48) | ((ulong(i)&short.max) << 33) | ((ulong(i)&short.max) << 18) | ((ulong(i)&short.max) << 3) | ((ulong(i)&short.max) >> 12);

    else static if(is(F == int) && is(T == byte))
        return byte(i >> 24);
    else static if(is(F == int) && is(T == short))
        return short(i >> 16);
    else static if(is(F == int) && is(T == long))
        return (long(i) << 32) | ((ulong(i)&int.max) << 1) | ((ulong(i)&int.max) >> 30);

    else static if(is(F == long) && is(T == byte))
        return byte(i >> 56);
    else static if(is(F == long) && is(T == short))
        return short(i >> 48);
    else static if(is(F == long) && is(T == int))
        return int(i >> 32);

    // signed -> unsigned
    else static if(is(F == byte) && is(T == ubyte))
        return ((ubyte(i)&byte.max) << 1) | ((ubyte(i)&byte.max) >> 6);
    else static if(is(F == byte) && is(T == ushort))
        return ((ushort(i)&byte.max) << 9) | ((ushort(i)&byte.max) << 2) | ((ushort(i)&byte.max) >> 5);
    else static if(is(F == byte) && is(T == uint))
        return ((uint(i)&byte.max) << 25) | ((uint(i)&byte.max) << 18) | ((uint(i)&byte.max) << 11) | ((uint(i)&byte.max) << 4) | ((uint(i)&byte.max) >> 3);
    else static if(is(F == byte) && is(T == ulong))
        return ((ulong(i)&byte.max) << 57) | ((ulong(i)&byte.max) << 50) | ((ulong(i)&byte.max) << 43) | ((ulong(i)&byte.max) << 36) | ((ulong(i)&byte.max) << 29) | ((ulong(i)&byte.max) << 22) | ((ulong(i)&byte.max) << 15) | ((ulong(i)&byte.max) << 8) | ((ulong(i)&byte.max) << 1) | ((ulong(i)&byte.max) >> 6);

    else static if(is(F == short) && is(T == ubyte))
        return cast(ubyte)((ushort(i)&short.max) >> 7);
    else static if(is(F == short) && is(T == ushort))
        return ((ushort(i)&short.max) << 1) | ((ushort(i)&short.max) >> 14);
    else static if(is(F == short) && is(T == uint))
        return ((uint(i)&short.max) << 17) | ((uint(i)&short.max) << 2) | ((uint(i)&short.max) >> 13);
    else static if(is(F == short) && is(T == ulong))
        return ((ulong(i)&short.max) << 49) | ((ulong(i)&short.max) << 34) | ((ulong(i)&short.max) << 19) | ((ulong(i)&short.max) << 4) | ((ulong(i)&short.max) >> 11);

    else static if(is(F == int) && is(T == ubyte))
        return cast(ubyte)((uint(i)&int.max) >> 23);
    else static if(is(F == int) && is(T == ushort))
        return cast(ushort)((uint(i)&int.max) >> 15);
    else static if(is(F == int) && is(T == uint))
        return ((uint(i)&int.max) << 1) | ((uint(i)&int.max) >> 30);
    else static if(is(F == int) && is(T == ulong))
        return ((ulong(i)&int.max) << 33) | ((ulong(i)&int.max) << 2) | ((ulong(i)&int.max) >> 29);

    else static if(is(F == long) && is(T == ubyte))
        return cast(byte)((ulong(i)&long.max) >> 55);
    else static if(is(F == long) && is(T == ushort))
        return cast(short)((ulong(i)&long.max) >> 47);
    else static if(is(F == long) && is(T == uint))
        return cast(int)((ulong(i)&long.max) >> 31);
    else static if(is(F == long) && is(T == ulong))
        return ((ulong(i)&long.max) << 1) | ((ulong(i)&long.max) >> 62);

    // unsigned -> signed
    else static if(is(F == ubyte) && is(T == byte))
        return byte(i >> 1);
    else static if(is(F == ubyte) && is(T == short))
        return short((ushort(i) << 7) | (i >> 1));
    else static if(is(F == ubyte) && is(T == int))
        return int((uint(i) << 23) | (uint(i) << 15) | (uint(i) << 7) | (i >> 1));
    else static if(is(F == ubyte) && is(T == long))
        return long((ulong(i) << 55) | (ulong(i) << 47) | (ulong(i) << 39) | (ulong(i) << 31) | (ulong(i) << 23) | (ulong(i) << 15) | (ulong(i) << 7) | (i >> 1));

    else static if(is(F == ushort) && is(T == byte))
        return byte(i >> 9);
    else static if(is(F == ushort) && is(T == short))
        return short(i >> 1);
    else static if(is(F == ushort) && is(T == int))
        return int((uint(i) << 15) | (i >> 1));
    else static if(is(F == ushort) && is(T == long))
        return long((ulong(i) << 47) | (ulong(i) << 31) | (ulong(i) << 15) | (i >> 1));

    else static if(is(F == uint) && is(T == byte))
        return byte(i >> 25);
    else static if(is(F == uint) && is(T == short))
        return short(i >> 17);
    else static if(is(F == uint) && is(T == int))
        return int(i >> 1);
    else static if(is(F == uint) && is(T == long))
        return long((ulong(i) << 31) | (i >> 1));

    else static if(is(F == ulong) && is(T == byte))
        return byte(i >> 57);
    else static if(is(F == ulong) && is(T == short))
        return short(i >> 49);
    else static if(is(F == ulong) && is(T == int))
        return int(i >> 33);
    else static if(is(F == ulong) && is(T == long))
        return long(i >> 1);

    else
        static assert(false, "Shouldn't be here! F: " ~ F.stringof ~ ", T: " ~ T.stringof);
}
