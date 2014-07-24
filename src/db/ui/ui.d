module db.ui.ui;

import db.tools.factory;
import db.ui.widget;
import db.ui.widgetevent;
import db.ui.inputmanager;
import db.ui.widgets.frame;
import db.ui.widgets.linearlayout;
import db.ui.widgets.label;
import db.ui.widgets.button;

import fuji.system;
import fuji.vector;
import fuji.matrix;
import fuji.input;
import fuji.dbg;

import std.string;


alias WidgetFactory = Factory!Widget;

class UserInterface
{
	// static stuff
	static bool registerWidget(T)(const(char)[] name = T.stringof) if(is(T : Widget))
	{
		return factory.registerType!T(name.toLower);
	}

	static bool registerWidgetRenderer(R, W)(const(char)[] name = W.stringof) if(is(R : WidgetRenderer) && is(W : Widget))
	{
		return renderFactory.registerType!R(name.toLower);
	}

	static Widget createWidget(const(char)[] widgetType)
	{
		widgetType = widgetType.toLower;

		if(!factory.exists(widgetType))
		{
			MFDebug_Log(2, "Widget type doesn't exist: " ~ widgetType);
			return null;
		}

		Widget widget;
		try widget = factory.create(widgetType);
		catch {}
		return widget;
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

	static void setActive(UserInterface ui) nothrow { active = ui; }
	static UserInterface getActive() nothrow { return active; }


	// methods
	this(MFRect displayRect)
	{
		root = createWidget!Frame();

		this.displayRect = displayRect;

		inputManager = new InputManager;
		inputManager.OnInputEvent ~= &onInputEvent;
	}

	final @property MFRect displayRect() const pure nothrow { return _displayRect; }
	final @property void displayRect(MFRect displayRect)
	{
		_displayRect = displayRect;
		root.position = MFVector(displayRect.x, displayRect.y);
		root.size = MFVector(displayRect.width, displayRect.height);
	}

	final void update()
	{
		inputManager.update();
		root.update();
	}

	final void draw()
	{
		root.draw();
	}

	final void addTopLevelWidget(Widget widget)
	{
		root.addChild(widget);
	}

	final void removeTopLevelWidget(Widget widget)
	{
		root.removeChild(widget);
	}

	final Widget setFocus(const(InputSource)* pSource, Widget focusWidget) pure nothrow
	{
		Widget old = focusList[pSource.sourceID];
		focusList[pSource.sourceID] = focusWidget;
		return old;
	}

	final inout(Widget) getFocus(const(InputSource)* pSource) inout pure nothrow
	{
		return focusList[pSource.sourceID];
	}

protected:
	MFRect _displayRect;

	Frame root;

	InputManager inputManager;

	Widget[InputManager.MaxSources] focusList;
	Widget[InputManager.MaxSources] hoverList;
	Widget[InputManager.MaxSources] downOver;

	static void localiseInput(InputManager.EventInfo* ev, Widget widget, ref const(MFVector) localPos) pure
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

				if(hover)
				{
					WidgetInputEvent ie = WidgetInputEvent(hover, ev.pSource);
					hover.OnHoverOut(hover, &ie.base);
				}

				if(widget)
				{
					WidgetInputEvent ie2 = WidgetInputEvent(widget, ev.pSource);
					widget.OnHoverOver(widget, &ie2.base);
				}
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
	}

	// static stuff
	__gshared UserInterface active;
	__gshared WidgetFactory factory;

	__gshared WidgetEvent.Handler[string] eventHandlerRegistry;

	shared static this()
	{
		UserInterface.registerWidget!Widget();
		UserInterface.registerWidget!Frame();
		UserInterface.registerWidget!LinearLayout();
		UserInterface.registerWidget!Label();
		UserInterface.registerWidget!Button();
	}
}
