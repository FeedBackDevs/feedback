module db.ui.widget;

import db.tools.event;
import db.tools.enumkvp;
import db.ui.ui;
import db.ui.inputmanager;
import db.ui.widgetstyle;
import db.ui.widgets.layout;

import fuji.dbg;
import fuji.types;
import fuji.vector;
import fuji.matrix;
import fuji.matrix;
import fuji.collision;

import std.traits;
import std.string;
import std.algorithm;
import std.range;
import std.conv;

import db.lua;


// TODO: move this back down into the classes protected section.
//       DMD bug causes compilation to fail is @noscript: is above imports
import fuji.texture;
import fuji.material;
import fuji.materials.standard;
import fuji.primitive;
import fuji.render;


enum Align
{
	None = -1,
	Left = 0,
	Center,
	Right,
	Fill
}

enum VAlign
{
	None = -1,
	Top = 0,
	Center,
	Bottom,
	Fill
}

enum Justification
{
	TopLeft = 0,
	TopCenter,
	TopRight,
	TopFill,
	CenterLeft,
	Center,
	CenterRight,
	CenterFill,
	BottomLeft,
	BottomCenter,
	BottomRight,
	BottomFill,
	FillLeft,
	FillCenter,
	FillRight,
	Fill,
	None
}

enum Visibility
{
	Visible = 0,
	Invisible,
	Gone
}

class Widget
{
	// properties
	@property string typeName() const pure nothrow @nogc { return Unqual!(typeof(this)).stringof; }

	final @property string id() const pure nothrow @nogc { return _id; }
	final @property void id(const(char)[] id) pure nothrow { _id = id.idup; }

	final @property string style() const pure nothrow @nogc { return _style; }
	final @property void style(const(char)[] style)
	{
		if (_style == style)
			return;

		_style = style.idup;

		if (enabled || !styleDisabled.length)
			applyStyle(style);
	}

	final @property string styleDisabled() const pure nothrow @nogc { return _styleDisabled; }
	final @property void styleDisabled(const(char)[] style)
	{
		if (_styleDisabled == style)
			return;

		_styleDisabled = style.idup;

		if (!enabled)
			applyStyle(style);
	}

	@noscript final @property inout(void)* userData() inout pure nothrow @nogc { return pUserData; }
	@noscript final @property void userData(void* pUserData) pure nothrow @nogc { this.pUserData = pUserData; }

	final @property bool enabled() const pure nothrow @nogc { return bEnabled && bParentEnabled; }
	final @property void enabled(bool enabled)
	{
		if (bEnabled == enabled)
			return;

		bEnabled = enabled;

		updateStyle();

		if (OnEnabledChanged)
			OnEnabledChanged(this, enabled);
	}

	final @property Visibility visibility() const pure nothrow @nogc { return visible; }
	final @property void visibility(Visibility visibility) nothrow
	{
		Visibility old = visible;
		if (visible != visibility)
		{
			visible = visibility;

			if ((old == Visibility.Gone || visible == Visibility.Gone) && OnLayoutChanged)
				OnLayoutChanged(this);
			if (OnVisibilityChanged)
				OnVisibilityChanged(this, visible);
		}
	}

	final @property int zdepth() const pure nothrow @nogc { return _parent ? _parent.getDepth(this) : -1; }
	final @property void zdepth(int depth) pure nothrow { if (_parent) _parent.setDepth(this, depth); }

	final @property bool clickable() const pure nothrow @nogc { return bClickable; }
	final @property void clickable(bool clickable) pure nothrow @nogc { bClickable = clickable; }
	final @property bool dragable() const pure nothrow @nogc { return bDragable; }
	final @property void dragable(bool dragable) pure nothrow @nogc { bDragable = dragable; }
	final @property bool hoverable() const pure nothrow @nogc { return bHoverable; }
	final @property void hoverable(bool hoverable) pure nothrow @nogc { bHoverable = hoverable; }

	final @property ref const(MFVector) position() const pure nothrow @nogc { return _position; }
	final @property void position(const(MFVector) position) nothrow
	{
		if (_position != position)
		{
			MFVector oldPos = _position;
			_position = position;

			dirtyMatrices();

			if (OnMove)
				OnMove(this, position, oldPos);
		}
	}

	final @property ref const(MFVector) size() const pure nothrow @nogc { return _size; }
	final @property MFVector sizeWithMargin() const pure nothrow @nogc { return MFVector(_size.x + _layoutMargin.x + _layoutMargin.z, _size.y + _layoutMargin.y + _layoutMargin.w, _size.z, _size.w); }
	final @property void size(const(MFVector) size) nothrow { bAutoWidth = bAutoHeight = false; resize(size); }

	final @property float width() const pure nothrow @nogc { return size.x; }
	final @property void width(float width) nothrow { bAutoWidth = false; updateWidth(width); }
	final @property float height() const pure nothrow @nogc { return  size.y; }
	final @property void height(float height) nothrow { bAutoHeight = false; updateHeight(height); }

	final @property ref const(MFVector) colour() const pure nothrow @nogc { return _colour; }
	final @property void colour(const(MFVector) colour) pure nothrow @nogc { _colour = colour; }

	final @property ref const(MFVector) scale() const pure nothrow @nogc { return _scale; }
	final @property void scale(const(MFVector) scale) pure nothrow @nogc
	{
		if (_scale != scale)
		{
			_scale = scale;
			dirtyMatrices();
		}
	}

	final @property ref const(MFVector) rotation() const pure nothrow @nogc { return _rotation; }
	final @property void rotation(const(MFVector) rotation) pure nothrow @nogc
	{
		if (_rotation != rotation)
		{
			_rotation = rotation;
			dirtyMatrices();
		}
	}

	final @property ref const(MFVector) layoutMargin() const pure nothrow @nogc { return _layoutMargin; }
	final @property void layoutMargin(const(MFVector) margin) nothrow
	{
		if (_layoutMargin != margin)
		{
			_layoutMargin = margin;

			if (OnLayoutChanged)
				OnLayoutChanged(this);
		}
	}

	final @property float layoutWeight() const pure nothrow @nogc { return _layoutWeight; }
	final @property void layoutWeight(float weight) nothrow
	{
		if (_layoutWeight != weight)
		{
			_layoutWeight = weight;

			if (OnLayoutChanged)
				OnLayoutChanged(this);
		}
	}

	final @property Justification layoutJustification() const pure nothrow @nogc { return _layoutJustification; }
	final @property void layoutJustification(Justification justification) nothrow
	{
		if (_layoutJustification != justification)
		{
			_layoutJustification = justification;

			if (OnLayoutChanged)
				OnLayoutChanged(this);
		}
	}

	final @property Align hAlign() const pure nothrow @nogc { return _layoutJustification == Justification.None ? Align.None : cast(Align)(_layoutJustification & 3); }
	final @property void hAlign(Align hAlign) nothrow
	{
		assert(hAlign != Align.None);
		layoutJustification = cast(Justification)((_layoutJustification & ~0x3) | hAlign);
	}
	final @property VAlign vAlign() const pure nothrow @nogc { return _layoutJustification == Justification.None ? VAlign.None : cast(VAlign)((_layoutJustification >> 2) & 3); }
	final @property void vAlign(VAlign vAlign) nothrow
	{
		assert(vAlign != VAlign.None);
		layoutJustification = cast(Justification)((_layoutJustification & ~0xC) | (vAlign << 2));
	}

	final @property ref const(MFMatrix) transform() pure nothrow @nogc
	{
		if (bMatrixDirty)
			buildTransform();
		return matrix;
	}

	final @property ref const(MFMatrix) invTransform() pure nothrow @nogc
	{
		if (bInvMatrixDirty)
		{
			invMatrix = transform.inverse;
			bInvMatrixDirty = false;
		}
		return invMatrix;
	}

	final @property UserInterface ui() const nothrow @nogc { return UserInterface.active; }

	// renderer properties
	final @property void bgImage(string image) { setRenderProperty("background_image", image); }

	final @property Justification bgAlign() const pure nothrow @nogc { return _imageAlignment; }
	final @property void bgAlign(Justification alignment) pure nothrow @nogc { _imageAlignment = alignment; }

	final @property ref const(MFVector) bgColour() const pure nothrow @nogc { return _bgColour; }
	final @property void bgColour(MFVector colour) pure nothrow @nogc { _bgColour = colour; }

	final @property ref const(MFVector) bgPadding() const pure nothrow @nogc { return _bgPadding; }
	final @property void bgPadding(MFVector padding) pure nothrow @nogc { _bgPadding = padding; }

	final @property ref const(MFVector) borderWidth() const pure nothrow @nogc { return _colour; }
	final @property void borderWidth(MFVector width) pure nothrow @nogc { _colour = width; }

	final @property ref const(MFVector) borderColour() const pure nothrow @nogc { return _colour; }
	final @property void borderColour(MFVector colour) pure nothrow @nogc { _colour = colour; }

	// methods
	final bool isType(const(char)[] type) const
	{
		foreach (T; BaseClassesTuple!(typeof(this)))
		{
			if (T.stringof == type)
				return true;
		}
		return false;
	}

	@noscript final InputEventDelegate registerInputEventHook(InputEventDelegate eventHook) pure nothrow @nogc { InputEventDelegate old = inputEventHook; inputEventHook = eventHook; return old; }

	final Widget setFocus(const(InputSource)* pSource)
	{
		return ui.setFocus(pSource, this);
	}

	void setProperty(const(char)[] property, const(char)[] value)
	{
		switch (property.toLower)
		{
			case "style":
				style = value; break;
			case "style_disabled":
				styleDisabled = value; break;
			case "enabled":
				enabled = getBoolFromString(value); break;
			case "visibility":
				visibility = getEnumValue!Visibility(value); break;
			case "clickable":
				clickable = getBoolFromString(value); break;
			case "dragable":
				dragable = getBoolFromString(value); break;
			case "hoverable":
				hoverable = getBoolFromString(value); break;
			case "zdepth":
				zdepth = to!int(value); break;
			case "weight":
				layoutWeight = to!float(value); break;
			case "position":
				position = getVectorFromString(value); break;
			case "size":
				size = getVectorFromString(value); break;
			case "width":
				width = to!float(value); break;
			case "height":
				height = to!float(value); break;
			case "scale":
				scale = getVectorFromString(value); break;
			case "colour":
				colour = getColourFromString(value); break;
			case "rotation":
				rotation = getVectorFromString(value); break;
			case "margin":
				layoutMargin = getVectorFromString(value); break;
			case "id":
				id = value; break;
			case "align":
				layoutJustification = getEnumValue!Justification(value); break;
			case "onenabledchanged":
				bindEvent!OnEnabledChanged(value); break;
			case "onvisibilitychanged":
				bindEvent!OnVisibilityChanged(value); break;
			case "onlayoutchanged":
				bindEvent!OnLayoutChanged(value); break;
			case "onmove":
				bindEvent!OnMove(value); break;
			case "onresize":
				bindEvent!OnResize(value); break;
			case "onfocuschanged":
				bindEvent!OnFocusChanged(value); break;
			case "ondown":
				clickable = true;
				bindEvent!OnDown(value); break;
			case "onup":
				clickable = true;
				bindEvent!OnUp(value); break;
			case "ontap":
				clickable = true;
				bindEvent!OnTap(value); break;
			case "ondrag":
				dragable = true;
				bindEvent!OnDrag(value); break;
			case "onhover":
				hoverable = true;
				bindEvent!OnHover(value); break;
			case "onhoverover":
				hoverable = true;
				bindEvent!OnHoverOver(value); break;
			case "onhoverout":
				hoverable = true;
				bindEvent!OnHoverOut(value); break;
			case "oncharacter":
				bindEvent!OnCharacter(value); break;
			default:
			{
				if (setRenderProperty(property, value, this))
					return;
				else
					ui.unknownProperty(this, property, value);
			}
		}
	}

	string getProperty(const(char)[] property)
	{
		switch (property.toLower)
		{
			case "id":
				return id;
			case "align":
				return getEnumFromValue(layoutJustification);
			default:
				return getRenderProperty(property);
		}
	}

	// widgets may have a lua table for app-specific data
	// we make this a property so that we don't allocate tables for widgets where it's never used
	@property LuaTable data()
	{
		if (_data.isNil)
			_data = createTable();
		return _data;
	}


	// support widget hierarchy
	@property inout(Widget)[] children() inout pure nothrow @nogc { return null; }
	final @property inout(Layout) parent() inout pure nothrow @nogc { return _parent; }

	final inout(Widget) findChild(const(char)[] id) inout pure nothrow @nogc
	{
		auto _children = children;
		foreach (child; _children)
		{
			if (child._id == id)
				return child;
		}
		foreach (child; _children)
		{
			auto found = child.findChild(id);
			if (found)
				return found;
		}
		return null;
	}

	final ptrdiff_t getChildIndex(Widget child) const pure nothrow @nogc
	{
		foreach (i, c; children)
		{
			if (c is child)
				return i;
		}
		return -1;
	}

	final int raise()
	{
		if (_parent)
			return _parent.raise(this);
		return -1;
	}

	final int lower()
	{
		if (_parent)
			return _parent.lower(this);
		return -1;
	}

	final int stackUnder(Widget under)
	{
		if (_parent)
			return _parent.stackUnder(this, under);
		return -1;
	}

	final int stackAbove(Widget above)
	{
		if (_parent)
			return _parent.stackAbove(this, above);
		return -1;
	}

	// state change events
	Event!(Widget, bool) OnEnabledChanged;
	Event!(Widget, Visibility) OnVisibilityChanged;

	Event!(Widget) OnLayoutChanged;

	// interactivity events
	Event!(Widget, MFVector, MFVector) OnMove;
	Event!(Widget, MFVector, MFVector) OnResize;
	Event!(Widget, bool, Widget, Widget) OnFocusChanged;

	// input events
	Event!(Widget, const(InputSource)*) OnDown;							// an input source lowered a key. applies to mouse, keyboard, touch, gamepad events
	Event!(Widget, const(InputSource)*) OnUp;							// an input source raised a key. applies to mouse, keyboard, touch, gamepad events
	Event!(Widget, const(InputSource)*) OnTap;							// a sequence of down followed by an up, without motion in between. applies to mouse, keyboard, touch, gamepad events
	Event!(Widget, const(InputSource)*, MFVector, MFVector) OnDrag;		// an input source was moved between a 'down', and 'up' event. applies to mouse, touch events
	Event!(Widget, const(InputSource)*, MFVector, MFVector) OnHover;	// an input source moved above a widget. applies to mouse events
	Event!(Widget, const(InputSource)*) OnHoverOver;					// an input source entered the bounds of a widget. applies to mouse events
	Event!(Widget, const(InputSource)*) OnHoverOut;						// an input source left the bounds of a widget. applies to mouse events

	Event!(Widget, const(InputSource)*, uint) OnCharacter;				// if the input was able to generate a unicode character

@noscript: // TODO: remove this when 'package' fix makes it to DMD.
//package(db.ui):
	// renderer stuff...
	MFVector _position;					// relative to parent
	MFVector _size;						// size of widget volume
	MFVector _colour = MFVector.white;	// colour modulation
	MFVector _scale = MFVector.one;		// scale the widget
	MFVector _rotation;					// rotation of the widget

	MFVector _layoutMargin;				// margin surrounding the widget within its container

	MFMatrix matrix;
	MFMatrix invMatrix;

	Layout _parent;

	InputEventDelegate inputEventHook;

	void *pUserData;

	string _id;

	string _style;
	string _styleDisabled;

	Visibility visible = Visibility.Visible;
	bool bEnabled = true;
	bool bParentEnabled = true;	// flagged if the parent is enabled

	bool bAutoWidth = true;
	bool bAutoHeight = true;
	bool bClickable, bDragable, bHoverable;

	Justification _layoutJustification = Justification.None;
	float _layoutWeight = 1;

	bool bMatrixDirty = true;
	bool bInvMatrixDirty = true;

	LuaTable _data;

	final @property void parent(Layout parent) pure nothrow @nogc { _parent = parent; }

	void update()
	{
		// update the children
		foreach (child; children)
			child.update();
	}

	final void draw()
	{
		if (visibility != Visibility.Visible)
			return;

		render();

		foreach (child; children)
			child.draw();
	}


	final void applyStyle(const(char)[] style)
	{
		if (style.empty)
			return;

		WidgetStyle* pStyle = WidgetStyle.findStyle(style);
		if (pStyle)
			pStyle.apply(this);
	}

	void updateStyle()
	{
		if (!bEnabled && !_styleDisabled.empty)
			applyStyle(_styleDisabled);
		else if (!_style.empty)
			applyStyle(_style);
	}

	final void dirtyMatrices() pure nothrow @nogc
	{
		bMatrixDirty = bInvMatrixDirty = true;
		foreach (child; children)
			child.dirtyMatrices();
	}

	final void resize(ref const(MFVector) size) nothrow
	{
		if (_size != size)
			doResize(size);
	}

	final void doResize(ref const(MFVector) size) nothrow
	{
		MFVector oldSize = _size;
		_size = size;

		if (OnResize)
			OnResize(this, size, oldSize);

		if (OnLayoutChanged)
			OnLayoutChanged(this);
	}

	final void buildTransform() pure nothrow @nogc
	{
		if (_rotation == MFVector.zero)
		{
			matrix.setScale(_scale);
		}
		else
		{
			// build the axiis from the rotation vector
			matrix.setRotationYPR(_rotation.y, _rotation.x, _rotation.z);

			// scale the axiis
			matrix.x = MFVector(matrix.x * _scale.x, 0);
			matrix.y = MFVector(matrix.y * _scale.y, 0);
			matrix.z = MFVector(matrix.z * _scale.z, 0);
		}

		// and set the position
		matrix.t = MFVector(_position, 1);

		// and multiply in the parent
		if (_parent)
			matrix = mul(_parent.transform, matrix);

		bMatrixDirty = false;
	}

	final void updateWidth(float width) nothrow		{ MFVector newSize = size; newSize.x = width; resize(newSize); }
	final void updateHeight(float height) nothrow	{ MFVector newSize = size; newSize.y = height; resize(newSize); }

	Widget intersectWidget(ref const(MFVector) pos, ref const(MFVector) dir, MFVector* pLocalPos) nothrow
	{
		if (visibility != Visibility.Visible)
			return null;

		if (_size.z == 0.0f)
		{
			// the widget is 2d, much easier

			// build a plane from the matrix
			MFVector plane;
			plane = -transform.z;

			// normalise if the plane is scaled along z
			if (_scale.z != 1.0f)
				plane *= 1.0f/_scale.z;

			// calculate w
			plane.w = -_position.dot3(plane);

			MFRayIntersectionResult res;
			if (MFCollision_RayPlaneTest(pos, dir, plane, &res))
			{
				MFVector intersection = invTransform.transformVectorH(pos + dir*res.time);

				if (pLocalPos)
					*pLocalPos = intersection;

				MFRect rect = MFRect(0, 0, _size.x, _size.y);
				if (MFTypes_PointInRect(intersection.x, intersection.y, rect))
				{
					Widget intersect = this;

					foreach (c; children.retro)
					{
						MFVector childLocal;
						Widget child = c.intersectWidget(pos, dir, &childLocal);
						if (child)
						{
							if (pLocalPos)
								*pLocalPos = childLocal;

							intersect = child;
							break;
						}
					}

					return intersect;
				}
			}
		}
		else
		{
			// intersect the 3d widgets cubic boundary
			//...
		}

		return null;
	}

	bool inputEvent(InputManager manager, const(InputManager.EventInfo)* ev)
	{
		// allow a registered hook to process the event...
		if (inputEventHook)
		{
			if (inputEventHook(manager, ev))
				return true;
		}

		// try and handle the input event in some standard ways...
		switch (ev.ev)
		{
			case InputManager.EventType.Down:
			{
				if (bClickable)
				{
					if (OnDown)
						OnDown(this, ev.pSource);
					return true;
				}
				break;
			}
			case InputManager.EventType.Up:
			{
				if (bClickable)
				{
					if (OnUp)
						OnUp(this, ev.pSource);
					return true;
				}
				break;
			}
			case InputManager.EventType.Tap:
			{
				if (bClickable)
				{
					if (OnTap)
						OnTap(this, ev.pSource);
					return true;
				}
				break;
			}
			case InputManager.EventType.Hover:
			{
				if (bHoverable)
				{
					if (OnHover)
						OnHover(this, ev.pSource, MFVector(ev.hover.x, ev.hover.y), MFVector(ev.hover.deltaX, ev.hover.deltaY));
					return true;
				}
				break;
			}
			case InputManager.EventType.Drag:
			{
				if (bDragable)
				{
					if (OnDrag)
						OnDrag(this, ev.pSource, MFVector(ev.hover.x, ev.hover.y), MFVector(ev.hover.deltaX, ev.hover.deltaY));
					return true;
				}
				break;
			}
			case InputManager.EventType.Pinch:
			case InputManager.EventType.Spin:
			case InputManager.EventType.ButtonTriggered:
			case InputManager.EventType.ButtonDown:
			case InputManager.EventType.ButtonUp:
			case InputManager.EventType.Wheel:
			default:
				break;
		}

		if (_parent)
			return _parent.inputEvent(manager, ev);
		return false;
	}


protected:
	MFVector _bgPadding;
	MFVector _bgColour;
	MFVector _border;		// width: left, top, right, bottom
	MFVector _borderColour;
	Material _image;
	Justification _imageAlignment = Justification.Center;
	float _texWidth = 0, _texHeight = 0;
	float _bg9CellMargin = 0;

	bool setRenderProperty(const(char)[] property, const(char)[] value, Widget widget = null)
	{
		switch (property.toLower)
		{
			case "background_image":
				_image.create(value);
				if (_image)
				{
					int texW, texH;
					Texture texture = _image.parameters[MFMatStandardParameters.Texture][MFMatStandardTextures.DifuseMap].asTexture;
					_texWidth = texture.width;
					_texHeight = texture.height;

					if (widget && (widget.bAutoWidth || widget.bAutoHeight))
					{
						if (widget.bAutoWidth && widget.bAutoHeight)
						{
							MFVector t = MFVector(_texWidth, _texHeight);
							widget.resize(t);
						}
						else if (widget.bAutoWidth)
							widget.updateWidth(_texWidth);
						else
							widget.updateHeight(_texHeight);
					}
				}
				return true;
			case "background_align":
				_imageAlignment = getEnumValue!(Justification)(value);
				return true;
			case "background_colour":
				_bgColour = getColourFromString(value);
				return true;
			case "background_padding":
				_bgPadding = getVectorFromString(value);
				return true;
			case "background_9-cell-margin":
				_bg9CellMargin = to!float(value);
				return true;
			case "border_width":
				_border = getVectorFromString(value);
				return true;
			case "border_colour":
				_borderColour = getColourFromString(value);
				return true;
			default:
		}
		return false;
	}

	string getRenderProperty(const(char)[] property)
	{
		MFDebug_Warn(2, format("Unknown property for '%s': %s", typeName, property));
		return null;
	}

	void render()
	{
		MFVector size = _size;
		size.x -= _bgPadding.x + _bgPadding.z;
		size.y -= _bgPadding.y + _bgPadding.w;

		if (_bgColour.w > 0)
		{
			float borderWidth = _border.x + _border.z;
			float borderHeight = _border.y + _border.w;
			MFVector wc = _bgColour*_colour;
			MFPrimitive_DrawUntexturedQuad(_bgPadding.x + _border.x, _bgPadding.y + _border.y, size.x - borderWidth, size.y - borderHeight, wc, transform);
		}

		MFVector bc = _borderColour*_colour;
		if (_border.x > 0) // left
			MFPrimitive_DrawUntexturedQuad(_bgPadding.x, _bgPadding.y, _border.x, size.y, bc, transform);
		if (_border.y > 0) // top
			MFPrimitive_DrawUntexturedQuad(_bgPadding.x, _bgPadding.y, size.x, _border.y, bc, transform);
		if (_border.z > 0) // right
			MFPrimitive_DrawUntexturedQuad(size.x - _border.z + _bgPadding.x, _bgPadding.y, _border.z, size.y, bc, transform);
		if (_border.w > 0) // bottom
			MFPrimitive_DrawUntexturedQuad(_bgPadding.x, _bgPadding.y + size.y - _border.w, size.x, _border.w, bc, transform);

		if (_image)
		{
			if (_bg9CellMargin > 0)
			{
				// 9 cell stuff...
			}
			else
			{
				// draw the background image centered in the box
				_image.setCurrent();

				float offset = 0;
				float tc = MFRenderer_GetTexelCenterOffset();
				if (tc > 0)
				{
					if (size.x == _texWidth && size.y == _texHeight)
						offset = tc;
				}

				MFPrimitive_DrawQuad(_bgPadding.x - offset, _bgPadding.y - offset, size.x, size.y, _colour, 0, 0, 1, 1, transform);
			}
		}
	}
}


bool getBoolFromString(const(char)[] value) pure
{
	if (!value.icmp("true") ||
		!value.icmp("1") ||
		!value.icmp("enabled") ||
		!value.icmp("on") ||
		!value.icmp("yes"))
		return true;
	return false;
}

MFVector getVectorFromString(const(char)[] value, MFVector defaultValue = MFVector.zero) pure
{
	float[4] f = [ defaultValue.x, defaultValue.y, defaultValue.z, defaultValue.w ];
	size_t numComponents;
	foreach (token; value.splitter(',').map!(a => a.strip))
	{
		f[numComponents++] = to!float(token);
		if (numComponents == 4)
			break;
	}
	if (numComponents == 1)
		f[1] = f[2] = f[3] = f[0];
	return MFVector(f[0], f[1], f[2], f[3]);
}

MFVector getColourFromString(const(char)[] value) pure
{
	if (!value.length)
		return MFVector.white;

	if (value.startsWith("#"))
	{
		assert(false, "Hex colours not supported... pester manu!");
		return MFVector.white;
	}

	switch (value.toLower)
	{
		case "black":
			return MFVector.black;
		case "white":
			return MFVector.white;
		case "red":
			return MFVector.red;
		case "blue":
			return MFVector.blue;
		case "green":
			return MFVector.green;
		case "yellow":
			return MFVector.yellow;
		case "orange":
			return MFVector.orange;
		case "grey":
			return MFVector.grey;
		case "lightgrey":
			return MFVector.lightgrey;
		case "darkgrey":
			return MFVector.darkgrey;
		default:
			break;
	}

	return getVectorFromString(value, MFVector.identity);
}
