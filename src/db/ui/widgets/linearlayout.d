module db.ui.widgets.linearlayout;

import db.ui.widget;
import db.ui.widgets.layout;
import db.tools.enumkvp;

import fuji.fuji;
import fuji.vector;

import std.string;
import std.traits : Unqual;

class LinearLayout : Layout
{
	enum Orientation
	{
		Horizontal,
		Vertical
	}

	override @property string typeName() const pure nothrow { return Unqual!(typeof(this)).stringof; }

	final Orientation orientation() const pure nothrow { return _orientation; }
	final void orientation(Orientation orientation)
	{
		_orientation = orientation;
		arrangeChildren();
	}

	override void setProperty(const(char)[] property, const(char)[] value)
	{
		if(!icmp(property, "orientation"))
			orientation = getEnumValue!Orientation(value);
		else
			super.setProperty(property, value);
	}

	override string getProperty(const(char)[] property)
	{
		if(!icmp(property, "orientation"))
			return getEnumFromValue(orientation);
		return super.getProperty(property);
	}


protected:
	Orientation _orientation = Orientation.Horizontal;

	override void arrangeChildren()
	{
		bool bFitWidth = bAutoWidth && hAlign != Align.Fill; // fitFlags & FitContentHorizontal
		bool bFitHeight = bAutoHeight && vAlign != VAlign.Fill; // fitFlags & FitContentVertical

		// early out?
		if(children.length == 0)
		{
			if(bFitWidth || bFitHeight)
			{
				// resize the layout
				MFVector newSize = size;
				if(bFitWidth)
					newSize.x = padding.x + padding.z;
				if(bFitHeight)
					newSize.y = padding.y + padding.w;
				resize(newSize);
			}
			return;
		}

		// calculate weight and fit
		float totalWeight = 0;
		MFVector fit = MFVector(padding.x + padding.z, padding.y + padding.w);
		foreach(widget; children)
		{
			if(widget.visibility == Visibility.Gone)
				continue;

			const(MFVector) cSize = widget.sizeWithMargin;

			if(orientation == Orientation.Horizontal)
			{
				if(widget.hAlign == Align.Fill) // fill horizontally
					totalWeight += widget.layoutWeight;
				else
					fit.x += cSize.x;

				fit.y = MFMax(fit.y, cSize.y + padding.y + padding.w);
			}
			else
			{
				if(widget.vAlign == VAlign.Fill) // fill vertically
					totalWeight += widget.layoutWeight;
				else
					fit.y += cSize.y;

				fit.x = MFMax(fit.x, cSize.x + padding.x + padding.z);
			}
		}

		if(bFitWidth || bFitHeight)
		{
			// resize the layout
			MFVector newSize = size;
			if(bFitWidth)
				newSize.x = fit.x;
			if(bFitHeight)
				newSize.y = fit.y;
			resize(newSize);
		}

		MFVector pPos = MFVector(padding.x, padding.y);
		MFVector pSize = MFVector(size.x - (padding.x + padding.z), size.y - (padding.y + padding.w));

		MFVector slack = max(size - fit, MFVector.zero);

		foreach(widget; children)
		{
			if(widget.visibility == Visibility.Gone)
				continue;

			const(MFVector) cMargin = widget.layoutMargin;
			const(MFVector) cSize = widget.size;

			MFVector tPos = pPos + MFVector(cMargin.x, cMargin.y);
			MFVector tSize = max(pSize - MFVector(cMargin.x + cMargin.z, cMargin.y + cMargin.w), MFVector.zero);

			Align halign = widget.hAlign;
			VAlign valign = widget.vAlign;

			MFVector newSize = cSize;

			if(orientation == Orientation.Horizontal)
			{
				if(halign == Align.Fill) // fill horizontally
				{
					// this widget fills available empty space in the parent container
					newSize.x = slack.x * (widget.layoutWeight / totalWeight);
					pPos.x += newSize.x;
					newSize.x = MFMax(0, newSize.x - cMargin.x - cMargin.z);
				}
				else
				{
					pPos.x += cSize.x + cMargin.x + cMargin.z;
				}

				final switch(valign) with(VAlign)
				{
					case None:
					case Top:
						widget.position = tPos;
						break;
					case Center:
						widget.position = tPos + MFVector(0, MFMax(tSize.y - cSize.y, 0) * 0.5f);
						break;
					case Bottom:
						widget.position = tPos + MFVector(0, MFMax(tSize.y - cSize.y, 0));
						break;
					case Fill:
						widget.position = tPos;
						newSize.y = tSize.y;
						break;
				}
			}
			else
			{
				if(valign == VAlign.Fill) // fill vertically
				{
					// this widget fills available empty space in the parent container
					newSize.y = slack.y * (widget.layoutWeight / totalWeight);
					pPos.y += newSize.y;
					newSize.y = MFMax(0, newSize.y - cMargin.y - cMargin.w);
				}
				else
				{
					pPos.y += cSize.y + cMargin.y + cMargin.w;
				}

				final switch(halign) with(Align)
				{
					case None:
					case Left:
						widget.position = tPos;
						break;
					case Center:
						widget.position = tPos + MFVector(MFMax(tSize.x - cSize.x, 0) * 0.5f, 0);
						break;
					case Right:
						widget.position = tPos + MFVector(MFMax(tSize.x - cSize.x, 0), 0);
						break;
					case Fill:
						widget.position = tPos;
						newSize.x = tSize.x;
						break;
				}
			}

			resizeChild(widget, newSize);
		}
	}
}
