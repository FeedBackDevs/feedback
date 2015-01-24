module db.ui.ui;

import db.tools.factory;
import db.ui.widget;
import db.ui.widgetevent;
import db.ui.inputmanager;
import db.ui.widgets.frame;
import db.ui.widgets.linearlayout;
import db.ui.widgets.label;
import db.ui.widgets.button;
import db.ui.widgets.prefab;
import db.ui.widgets.textbox;
import db.ui.widgets.listbox;

import fuji.system;
import fuji.vector;
import fuji.matrix;
import fuji.input;
import fuji.font;
import fuji.dbg;

import luad.base;

import std.string;


alias WidgetFactory = Factory!Widget;

class UserInterface
{
	alias InputEventDelegate = bool delegate(InputManager, const(InputManager.EventInfo)*);
	alias UnknownPropertyDelegate = void delegate(Widget, const(char)[] property, const(char)[] value);

	static Widget createWidget(const(char)[] widgetType)
	{
		widgetType = widgetType.toLower;

		if(!_factory.exists(widgetType))
		{
			MFDebug_Log(2, "Widget type doesn't exist: " ~ widgetType);
			return null;
		}

		Widget widget;
		try widget = _factory.create(widgetType);
		catch {}
		return widget;
	}

	final @property MFRect displayRect() const pure nothrow { return _displayRect; }
	final @property void displayRect(MFRect displayRect)
	{
		_displayRect = displayRect;
		root.position = MFVector(displayRect.x, displayRect.y);
		root.size = MFVector(displayRect.width, displayRect.height);
	}

	final void addTopLevelWidget(Widget widget)
	{
		root.addChild(widget);
	}

	final void removeTopLevelWidget(Widget widget)
	{
		root.removeChild(widget);
	}

	final Widget setFocus(const(InputSource)* pSource, Widget focusWidget)
	{
		Widget old = focusList[pSource.sourceID];

		if(old && old.OnFocusChanged)
			old.OnFocusChanged(old, false, focusWidget, old);

		focusList[pSource.sourceID] = focusWidget;

		if(focusWidget && focusWidget.OnFocusChanged)
			focusWidget.OnFocusChanged(focusWidget, true, focusWidget, old);

		return old;
	}

	final inout(Widget) getFocus(const(InputSource)* pSource) inout pure nothrow @nogc
	{
		return focusList[pSource.sourceID];
	}

	final inout(Widget) find(const(char)[] id) inout pure nothrow @nogc
	{
		return root.findChild(id);
	}

	final inout(Widget) opDispatch(string id)() inout
	{
		return root.findChild(id);
	}

	static void active(UserInterface ui) nothrow { _active = ui; }
	static UserInterface active() nothrow @nogc { return _active; }

	final InputEventDelegate registerInputEventHook(InputEventDelegate eventHook) pure nothrow @nogc { InputEventDelegate old = inputEventHook; inputEventHook = eventHook; return old; }
	final InputEventDelegate registerUnhandledInputHandler(InputEventDelegate handler) pure nothrow @nogc { InputEventDelegate old = unhandledEventHandler; unhandledEventHandler = handler; return old; }
	final UnknownPropertyDelegate registerUnknownPropertyHandler(UnknownPropertyDelegate handler) pure nothrow @nogc { UnknownPropertyDelegate old = unknownPropertyHandler; unknownPropertyHandler = handler; return old; }

@noscript:
	// static stuff
	static bool registerWidget(T)(const(char)[] name = T.stringof) if(is(T : Widget))
	{
		return _factory.registerType!T(name.toLower);
	}

	static bool registerWidgetRenderer(R, W)(const(char)[] name = W.stringof) if(is(R : WidgetRenderer) && is(W : Widget))
	{
		return renderFactory.registerType!R(name.toLower);
	}

	static T createWidget(T)() if(is(T : Widget))
	{
		return cast(T)createWidget(T.stringof);
	}

	static void registerEventHandler(const(char)[] name, WidgetEvent.Handler handler)
	{
		if(name in eventHandlerRegistry)
		{
			MFDebug_Log(2, "Event handler already registered: " ~ name);
			return;
		}

		eventHandlerRegistry[name] = handler;
	}

	static WidgetEvent.Handler getEventHandler(const(char)[] name) { return name in eventHandlerRegistry ? eventHandlerRegistry[name] : null; }


	// methods
	this(MFRect displayRect)
	{
		root = createWidget!Frame();
		root.id = "ui-root";

		this.displayRect = displayRect;

		inputManager = new InputManager;
		inputManager.OnInputEvent ~= &onInputEvent;
	}

	final void update()
	{
		inputManager.update();
		root.update();
	}

	final void draw()
	{
		root.draw();
/+
		Font font = Font.debugFont;
		if(hoverList[0])
			font.draw(hoverList[0].id ? hoverList[0].id : hoverList[0].typeName, 100, 100, 20);
		else
			font.draw("none", 100, 100, 20);
+/
	}

package:
	void unknownProperty(Widget widget, const(char)[] property, const(char)[] value)
	{
		if(unknownPropertyHandler)
			unknownPropertyHandler(widget, property, value);
		else
			MFDebug_Warn(2, format("Unknown property for '%s' %s=\"%s\"", widget.typeName, property, value));
	}

protected:
	MFRect _displayRect;

	Frame root;

	InputManager inputManager;

	Widget[InputManager.MaxSources] focusList;
	Widget[InputManager.MaxSources] hoverList;
	Widget[InputManager.MaxSources] downOver;

	InputEventDelegate inputEventHook;
	InputEventDelegate unhandledEventHandler;
	UnknownPropertyDelegate unknownPropertyHandler;

	static void localiseInput(InputManager.EventInfo* ev, Widget widget, ref const(MFVector) localPos) pure nothrow @nogc
	{
		ev.hover.x = localPos.x;
		ev.hover.y = localPos.y;

		if(ev.ev == InputManager.EventType.Hover || ev.ev == InputManager.EventType.Drag)
		{
			// transform delta
			MFVector transformedDelta = widget.invTransform.transformVector3(MFVector(ev.hover.deltaX, ev.hover.deltaY));
			ev.hover.deltaX = transformedDelta.x;
			ev.hover.deltaY = transformedDelta.y;
		}

		if(ev.ev == InputManager.EventType.Drag)
		{
			// transform secondary position
			MFVector transformedStart = widget.invTransform.transformVectorH(MFVector(ev.drag.startX, ev.drag.startY));
			ev.drag.startX = transformedStart.x;
			ev.drag.startY = transformedStart.y;
		}
	}

	final void onInputEvent(InputManager manager, const(InputManager.EventInfo)* ev)
	{
		// allow a registered hook to process the event...
		if(inputEventHook)
		{
			if(inputEventHook(manager, ev))
				return;
		}

		// get focus widget
		Widget focusWidget = focusList[ev.pSource.sourceID];

		if(ev.pSource.device == MFInputDevice.Mouse || ev.pSource.device == MFInputDevice.TouchPanel)
		{
			// positional events will be sent to the hierarchy
			MFVector pos = MFVector(ev.hover.x, ev.hover.y, 0, 1);
			MFVector dir = MFVector(0, 0, 1, 1);

			MFVector localPos;

			Widget widget = null;
			if(focusWidget)
			{
				widget = focusWidget.intersectWidget(pos, dir, &localPos);
				if(!widget)
					widget = focusWidget;
			}
			else
			{
				widget = root.intersectWidget(pos, dir, &localPos);
			}

			// update the down widget
			if(ev.ev == InputManager.EventType.Down)
				downOver[ev.pSource.sourceID] = widget;
			else if(ev.ev == InputManager.EventType.Tap)
			{
				// if we receive a tap event, check that it was on the same widget we recorded the down event for
				if(downOver[ev.pSource.sourceID] != widget)
					return;
			}

			// check if the hover has changed
			Widget hover = hoverList[ev.pSource.sourceID];
			if(hover != widget)
			{
				hoverList[ev.pSource.sourceID] = widget;

				if(hover && hover.OnHoverOut)
					hover.OnHoverOut(hover, ev.pSource);
				if(widget && widget.OnHoverOver)
					widget.OnHoverOver(widget, ev.pSource);
			}

			if(widget)
			{
				InputManager.EventInfo transformedEv = *ev;
				localiseInput(&transformedEv, widget, localPos);

				// send the input event
				if(widget.inputEvent(manager, &transformedEv))
					return;
			}
		}
		else if(focusWidget)
		{
			// non-positional events
			focusWidget.inputEvent(manager, ev);
		}
		else
		{
			unhandledEventHandler(manager, ev);
		}
	}

	// static stuff
	__gshared UserInterface _active;
	__gshared WidgetFactory _factory;

	__gshared WidgetEvent.Handler[string] eventHandlerRegistry;

	shared static this()
	{
		UserInterface.registerWidget!Widget();
		UserInterface.registerWidget!Frame();
		UserInterface.registerWidget!LinearLayout();
		UserInterface.registerWidget!Label();
		UserInterface.registerWidget!Button();
		UserInterface.registerWidget!Textbox();
		UserInterface.registerWidget!Listbox();
		UserInterface.registerWidget!Prefab();
	}
}
