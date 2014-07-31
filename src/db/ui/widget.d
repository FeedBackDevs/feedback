module db.ui.widget;

import db.tools.event;
import db.tools.enumkvp;
import db.ui.ui;
import db.ui.inputmanager;
import db.ui.widgetevent;
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

class Widget
{
	alias InputEventDelegate = bool delegate(InputManager, const(InputManager.EventInfo)*);

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

	// properties
	final @property string typeName() const { return typeof(this).stringof; }

	final @property string id() const pure nothrow { return _id; }
	final @property void id(const(char)[] id) pure nothrow { _id = id.idup; }

	final @property string style() const pure nothrow { return _style; }
	final @property void style(const(char)[] style)
	{
		if(_style == style)
			return;

		_style = style.idup;

		if(enabled || !styleDisabled.length)
			applyStyle(style);
	}

	final @property string styleDisabled() const pure nothrow { return _styleDisabled; }
	final @property void styleDisabled(const(char)[] style)
	{
		if(_styleDisabled == style)
			return;

		_styleDisabled = style.idup;

		if(!enabled)
			applyStyle(style);
	}

	final @property inout(void)* userData() inout pure nothrow { return pUserData; }
	final @property void userData(void* pUserData) pure nothrow { this.pUserData = pUserData; }

	final @property bool enabled() const pure nothrow { return bEnabled && bParentEnabled; }
	final @property void enabled(bool enabled)
	{
		if(bEnabled == enabled)
			return;

		bEnabled = enabled;

		updateStyle();

		if(!OnEnabledChanged.empty)
		{
			WidgetEnabledEvent ev = WidgetEnabledEvent(this, enabled);
			OnEnabledChanged(this, &ev.base);
		}
	}

	final @property Visibility visibility() const pure nothrow { return visible; }
	final @property void visibility(Visibility visibility)
	{
		Visibility old = visible;
		if(visible != visibility)
		{
			visible = visibility;

			if(old == Visibility.Gone || visible == Visibility.Gone)
			{
				WidgetGeneralEvent ev = WidgetGeneralEvent(this);
				OnLayoutChanged(this, &ev.base);
			}

			if(!OnVisibleChanged.empty)
			{
				WidgetVisibilityEvent ev = WidgetVisibilityEvent(this, visible);
				OnVisibleChanged(this, &ev.base);
			}
		}
	}

	final @property int zdepth() const pure nothrow { return _parent ? _parent.getDepth(this) : -1; }
	final @property void zdepth(int depth) pure nothrow { if(_parent) _parent.setDepth(this, depth); }

	final @property bool clickable() const pure nothrow { return bClickable; }
	final @property void clickable(bool clickable) pure nothrow { bClickable = clickable; }
	final @property bool dragable() const pure nothrow { return bDragable; }
	final @property void dragable(bool dragable) pure nothrow { bDragable = dragable; }
	final @property bool hoverable() const pure nothrow { return bHoverable; }
	final @property void hoverable(bool hoverable) pure nothrow { bHoverable = hoverable; }

	final @property ref const(MFVector) position() const pure nothrow { return _position; }
	final @property void position(const(MFVector) position)
	{
		if(_position != position)
		{
			MFVector oldPos = _position;
			_position = position;

			dirtyMatrices();

			if(!OnMove.empty)
			{
				WidgetMoveEvent ev = WidgetMoveEvent(this);
				ev.oldPos = oldPos;
				ev.newPos = position;
				OnMove(this, &ev.base);
			}
		}
	}

	final @property ref const(MFVector) size() const pure nothrow { return _size; }
	final @property MFVector sizeWithMargin() const pure nothrow { return MFVector(_size.x + _layoutMargin.x + _layoutMargin.z, _size.y + _layoutMargin.y + _layoutMargin.w, _size.z, _size.w); }
	final @property void size(const(MFVector) size) { bAutoWidth = bAutoHeight = false; resize(size); }

	final @property float width() const pure nothrow { return size.x; }
	final @property void width(float width) { bAutoWidth = false; updateWidth(width); }
	final @property float height() const pure nothrow { return  size.y; }
	final @property void height(float height) { bAutoHeight = false; updateHeight(height); }

	final @property ref const(MFVector) colour() const pure nothrow { return _colour; }
	final @property void colour(const(MFVector) colour) pure nothrow { _colour = colour; }

	final @property ref const(MFVector) scale() const pure nothrow { return _scale; }
	final @property void scale(const(MFVector) scale) pure nothrow
	{
		if(_scale != scale)
		{
			_scale = scale;
			dirtyMatrices();
		}
	}

	final @property ref const(MFVector) rotation() const pure nothrow { return _rotation; }
	final @property void rotation(const(MFVector) rotation) pure nothrow
	{
		if(_rotation != rotation)
		{
			_rotation = rotation;
			dirtyMatrices();
		}
	}

	final @property ref const(MFVector) layoutMargin() const pure nothrow { return _layoutMargin; }
	final @property void layoutMargin(const(MFVector) margin)
	{
		if(_layoutMargin != margin)
		{
			_layoutMargin = margin;

			WidgetGeneralEvent ev = WidgetGeneralEvent(this);
			OnLayoutChanged(this, &ev.base);
		}
	}

	final @property float layoutWeight() const pure nothrow { return _layoutWeight; }
	final @property void layoutWeight(float weight)
	{
		if(_layoutWeight != weight)
		{
			_layoutWeight = weight;

			WidgetGeneralEvent ev = WidgetGeneralEvent(this);
			OnLayoutChanged(this, &ev.base);
		}
	}

	final @property Justification layoutJustification() const pure nothrow { return _layoutJustification; }
	final @property void layoutJustification(Justification justification)
	{
		if(_layoutJustification != justification)
		{
			_layoutJustification = justification;

			WidgetGeneralEvent ev = WidgetGeneralEvent(this);
			OnLayoutChanged(this, &ev.base);
		}
	}

	final @property Align hAlign() const pure nothrow { return _layoutJustification == Justification.None ? Align.None : cast(Align)(_layoutJustification & 3); }
	final @property void hAlign(Align hAlign)
	{
		assert(hAlign != Align.None);
		layoutJustification = cast(Justification)((_layoutJustification & ~0x3) | hAlign);
	}
	final @property VAlign vAlign() const pure nothrow { return _layoutJustification == Justification.None ? VAlign.None : cast(VAlign)((_layoutJustification >> 2) & 3); }
	final @property void vAlign(VAlign vAlign)
	{
		assert(vAlign != VAlign.None);
		layoutJustification = cast(Justification)((_layoutJustification & ~0xC) | (vAlign << 2));
	}

	final @property ref const(MFMatrix) transform() pure nothrow
	{
		if(bMatrixDirty)
			buildTransform();
		return matrix;
	}

	final @property ref const(MFMatrix) invTransform() pure nothrow
	{
		if(bInvMatrixDirty)
		{
			invMatrix = transform.inverse;
			bInvMatrixDirty = false;
		}
		return invMatrix;
	}


	// methods
	final UserInterface getUI() const { return UserInterface.getActive(); }

	final bool isType(const(char)[] type) const
	{
		foreach(T; BaseClassesTuple!(typeof(this)))
		{
			if(T.stringof == type)
				return true;
		}
		return false;
	}

	final InputEventDelegate registerInputEventHook(InputEventDelegate eventHook) pure nothrow { InputEventDelegate old = inputEventHook; inputEventHook = eventHook; return old; }

	void setProperty(const(char)[] property, const(char)[] value)
	{
		switch(property.toLower)
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
				bindWidgetEvent(OnEnabledChanged, value); break;
			case "onvisiblechanged":
				bindWidgetEvent(OnVisibleChanged, value); break;
			case "onlayoutchanged":
				bindWidgetEvent(OnLayoutChanged, value); break;
			case "onmove":
				bindWidgetEvent(OnMove, value); break;
			case "onresize":
				bindWidgetEvent(OnResize, value); break;
			case "onfocuschanged":
				bindWidgetEvent(OnFocusChanged, value); break;
			case "ondown":
				clickable = true;
				bindWidgetEvent(OnDown, value); break;
			case "onup":
				clickable = true;
				bindWidgetEvent(OnUp, value); break;
			case "ontap":
				clickable = true;
				bindWidgetEvent(OnTap, value); break;
			case "ondrag":
				dragable = true;
				bindWidgetEvent(OnDrag, value); break;
			case "onhover":
				hoverable = true;
				bindWidgetEvent(OnHover, value); break;
			case "onhoverover":
				hoverable = true;
				bindWidgetEvent(OnHoverOver, value); break;
			case "onhoverout":
				hoverable = true;
				bindWidgetEvent(OnHoverOut, value); break;
			case "oncharacter":
				bindWidgetEvent(OnCharacter, value); break;
			default:
			{
				if(setRenderProperty(property, value, this))
					return;
				else
					MFDebug_Warn(2, format("Unknown property for '%s' %s=\"%s\"", typeName, property, value));
			}
		}
	}

	string getProperty(const(char)[] property)
	{
		switch(property.toLower)
		{
			case "id":
				return id;
			case "align":
				return getEnumFromValue!Justification(layoutJustification);
			default:
				return getRenderProperty(property);
		}
		return null;
	}


	// support widget hierarchy
	@property Widget[] children() pure nothrow { return null; }
	final @property Layout parent() { return _parent; }

	final Widget findChild(const(char)[] name)
	{
		Widget[] _children = children;
		foreach(child; _children)
		{
			if(!child._id.icmp(name))
				return child;
		}
		foreach(child; _children)
		{
			Widget found = child.findChild(name);
			if(found)
				return found;
		}
		return null;
	}


	// state change events
	WidgetEvent OnEnabledChanged;
	WidgetEvent OnVisibleChanged;

	WidgetEvent OnLayoutChanged;

	// interactivity events
	WidgetEvent OnMove;
	WidgetEvent OnResize;
	WidgetEvent OnFocusChanged;

	// input events
	WidgetEvent OnDown;			// an input source lowered a key. applies to mouse, keyboard, touch, gamepad events
	WidgetEvent OnUp;			// an input source raised a key. applies to mouse, keyboard, touch, gamepad events
	WidgetEvent OnTap;			// a sequence of down followed by an up, without motion in between. applies to mouse, keyboard, touch, gamepad events
	WidgetEvent OnDrag;			// an input source was moved between a 'down', and 'up' event. applies to mouse, touch events
	WidgetEvent OnHover;		// an input source moved above a widget. applies to mouse events
	WidgetEvent OnHoverOver;	// an input source entered the bounds of a widget. applies to mouse events
	WidgetEvent OnHoverOut;		// an input source left the bounds of a widget. applies to mouse events

	WidgetEvent OnCharacter;	// if the input was able to generate a unicode character

//FIXME: package:
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

	final @property void parent(Layout parent) { _parent = parent; }

	void update()
	{
		// update the children
		foreach(child; children)
			child.update();
	}

	final void draw()
	{
		if(visibility != Visibility.Visible)
			return;

		render();

		foreach(child; children)
			child.draw();
	}


	final void applyStyle(const(char)[] style)
	{
		if(style.empty)
			return;

		WidgetStyle* pStyle = WidgetStyle.findStyle(style);
		if(pStyle)
			pStyle.apply(this);
	}

	void updateStyle()
	{
		if(!bEnabled && !_styleDisabled.empty)
			applyStyle(_styleDisabled);
		else if(!_style.empty)
			applyStyle(_style);
	}

	final void dirtyMatrices() pure nothrow
	{
		bMatrixDirty = bInvMatrixDirty = true;
		foreach(child; children)
			child.dirtyMatrices();
	}

	final void resize(ref const(MFVector) size)
	{
		if(_size != size)
			doResize(size);
	}

	final void doResize(ref const(MFVector) size)
	{
		MFVector oldSize = _size;
		_size = size;

		if(!OnResize.empty)
		{
			WidgetResizeEvent ev = WidgetResizeEvent(this);
			ev.oldSize = oldSize;
			ev.newSize = size;
			OnResize(this, &ev.base);
		}

		WidgetGeneralEvent ev = WidgetGeneralEvent(this);
		OnLayoutChanged(this, &ev.base);
	}

	final void buildTransform() pure nothrow
	{
		if(_rotation == MFVector.zero)
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
		if(_parent)
			matrix = mul(_parent.transform, matrix);

		bMatrixDirty = false;
	}

	final void updateWidth(float width)		{ MFVector newSize = size; newSize.x = width; resize(newSize); }
	final void updateHeight(float height)	{ MFVector newSize = size; newSize.y = height; resize(newSize); }

	Widget intersectWidget(ref const(MFVector) pos, ref const(MFVector) dir, MFVector* pLocalPos)
	{
		if(visibility != Visibility.Visible)
			return null;

		if(_size.z == 0.0f)
		{
			// the widget is 2d, much easier

			// build a plane from the matrix
			MFVector plane;
			plane = -transform.z;

			// normalise if the plane is scaled along z
			if(_scale.z != 1.0f)
				plane *= 1.0f/_scale.z;

			// calculate w
			plane.w = -_position.dot3(plane);

			MFRayIntersectionResult res;
			if(MFCollision_RayPlaneTest(pos, dir, plane, &res))
			{
				MFVector intersection = invTransform.transformVectorH(pos + dir*res.time);

				if(pLocalPos)
					*pLocalPos = intersection;

				MFRect rect = MFRect(0, 0, _size.x, _size.y);
				if(MFTypes_PointInRect(intersection.x, intersection.y, rect))
				{
					Widget intersect = this;

					foreach(c; children.retro)
					{
						MFVector childLocal;
						Widget child = c.intersectWidget(pos, dir, &childLocal);
						if(child)
						{
							if(pLocalPos)
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
		if(inputEventHook)
		{
			if(inputEventHook(manager, ev))
				return true;
		}

		// try and handle the input event in some standard ways...
		switch(ev.ev)
		{
			case InputManager.EventType.Down:
			{
				if(bClickable)
				{
					WidgetInputEvent ie = WidgetInputEvent(this, ev.pSource);
					OnDown(this, &ie.base);
					return true;
				}
				break;
			}
			case InputManager.EventType.Up:
			{
				if(bClickable)
				{
					WidgetInputEvent ie = WidgetInputEvent(this, ev.pSource);
					OnUp(this, &ie.base);
					return true;
				}
				break;
			}
			case InputManager.EventType.Tap:
			{
				if(bClickable)
				{
					WidgetInputEvent ie = WidgetInputEvent(this, ev.pSource);
					OnTap(this, &ie.base);
					return true;
				}
				break;
			}
			case InputManager.EventType.Hover:
			{
				if(bHoverable)
				{
					WidgetInputActionEvent ie = WidgetInputActionEvent(this, ev.pSource);
					ie.pos = MFVector(ev.hover.x, ev.hover.y);
					ie.delta = MFVector(ev.hover.deltaX, ev.hover.deltaY);
					OnHover(this, &ie.base);
					return true;
				}
				break;
			}
			case InputManager.EventType.Drag:
			{
				if(bDragable)
				{
					WidgetInputActionEvent ie = WidgetInputActionEvent(this, ev.pSource);
					ie.pos = MFVector(ev.hover.x, ev.hover.y);
					ie.delta = MFVector(ev.hover.deltaX, ev.hover.deltaY);
					OnDrag(this, &ie.base);
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

		if(_parent)
			return _parent.inputEvent(manager, ev);
		return false;
	}


protected:
	// renderer stuff...
	import fuji.texture;
	import fuji.material;
	import fuji.materials.standard;
	import fuji.primitive;
	import fuji.render;

	MFVector bgPadding;
	MFVector bgColour;
	MFVector border;		// width: left, top, right, bottom
	MFVector borderColour;
	Material image;
	Widget.Justification imageAlignment = Widget.Justification.Center;
	float texWidth, texHeight;
	float bg9CellMargin;

	bool setRenderProperty(const(char)[] property, const(char)[] value, Widget widget = null)
	{
		switch(property.toLower)
		{
			case "background_image":
				image.create(value);
				if(image)
				{
					int texW, texH;
					Texture texture = image.parameters[MFMatStandardParameters.Texture][MFMatStandardTextures.DifuseMap].asTexture;
					texWidth = texture.width;
					texHeight = texture.height;

					if(widget && (widget.bAutoWidth || widget.bAutoHeight))
					{
						if(widget.bAutoWidth && widget.bAutoHeight)
						{
							MFVector t = MFVector(texWidth, texHeight);
							widget.resize(t);
						}
						else if(widget.bAutoWidth)
							widget.updateWidth(texWidth);
						else
							widget.updateHeight(texHeight);
					}
				}
				return true;
			case "background_align":
				imageAlignment = getEnumValue!(Widget.Justification)(value);
				return true;
			case "background_colour":
				bgColour = getColourFromString(value);
				return true;
			case "background_padding":
				bgPadding = getVectorFromString(value);
				return true;
			case "background_9-cell-margin":
				bg9CellMargin = to!float(value);
				return true;
			case "border_width":
				border = getVectorFromString(value);
				return true;
			case "border_colour":
				borderColour = getColourFromString(value);
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
		size.x -= bgPadding.x + bgPadding.z;
		size.y -= bgPadding.y + bgPadding.w;

		if(bgColour.w > 0)
		{
			float borderWidth = border.x + border.z;
			float borderHeight = border.y + border.w;
			MFVector wc = bgColour*_colour;
			MFPrimitive_DrawUntexturedQuad(bgPadding.x + border.x, bgPadding.y + border.y, size.x - borderWidth, size.y - borderHeight, wc, transform);
		}

		MFVector bc = borderColour*_colour;
		if(border.x > 0) // left
			MFPrimitive_DrawUntexturedQuad(bgPadding.x, bgPadding.y, border.x, size.y, bc, transform);
		if(border.y > 0) // top
			MFPrimitive_DrawUntexturedQuad(bgPadding.x, bgPadding.y, size.x, border.y, bc, transform);
		if(border.z > 0) // right
			MFPrimitive_DrawUntexturedQuad(size.x - border.z + bgPadding.x, bgPadding.y, border.z, size.y, bc, transform);
		if(border.w > 0) // bottom
			MFPrimitive_DrawUntexturedQuad(bgPadding.x, bgPadding.y + size.y - border.w, size.x, border.w, bc, transform);

		if(image)
		{
			if(bg9CellMargin > 0)
			{
				// 9 cell stuff...
			}
			else
			{
				// draw the background image centered in the box
				image.setCurrent();

				float offset = 0;
				float tc = MFRenderer_GetTexelCenterOffset();
				if(tc > 0)
				{
					if(size.x == texWidth && size.y == texHeight)
						offset = tc;
				}

				MFPrimitive_DrawQuad(bgPadding.x - offset, bgPadding.y - offset, size.x, size.y, _colour, 0, 0, 1, 1, transform);
			}
		}
	}
}


bool getBoolFromString(const(char)[] value)
{
	if(!value.icmp("true") ||
		!value.icmp("1") ||
		!value.icmp("enabled") ||
		!value.icmp("on") ||
		!value.icmp("yes"))
		return true;
	return false;
}

MFVector getVectorFromString(const(char)[] value, MFVector defaultValue = MFVector.zero)
{
	float[4] f = [ defaultValue.x, defaultValue.y, defaultValue.z, defaultValue.w ];
	size_t numComponents;
	foreach(token; value.splitter(',').map!(a => a.strip))
	{
		f[numComponents++] = to!float(token);
		if(numComponents == 4)
			break;
	}
	if(numComponents == 1)
		f[1] = f[2] = f[3] = f[0];
	return MFVector(f[0], f[1], f[2], f[3]);
}

MFVector getColourFromString(const(char)[] value)
{
	if(!value.length)
		return MFVector.white;

	if(value.startsWith("$", "0x"))
	{
		assert(false, "Hex colours not supported... pester manu!");
		return MFVector.white;
	}

	switch(value.toLower)
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

import luad.lfunction;
import db.game;
struct LuaDelegate
{
	string func;

	final void luaCall(Widget widget, const(WidgetEventInfo)* ev)
	{
		LuaFunction lfunc = Game.instance.lua.get!LuaFunction(func);
		lfunc.call();
	}
}

void bindWidgetEvent(ref WidgetEvent event, const(char)[] eventName)
{
	WidgetEvent.Handler d = UserInterface.getEventHandler(eventName);
	if(!d)
	{
		LuaDelegate* ld = new LuaDelegate(eventName.idup);
		d = &ld.luaCall;
	}
	event ~= d;
}
