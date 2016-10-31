module db.ui.widgets.frame;

import db.ui.ui;
import db.ui.widget;
import db.ui.widgets.layout;

import fuji.fuji;
import fuji.vector;

import std.range;
import std.traits : Unqual;

class Frame : Layout
{
	override @property string typeName() const pure nothrow { return Unqual!(typeof(this)).stringof; }

protected:
	override void arrangeChildren()
	{
		bool bFitWidth = bAutoWidth && hAlign != Align.Fill; // fitFlags & FitContentHorizontal
		bool bFitHeight = bAutoHeight && vAlign != VAlign.Fill; // fitFlags & FitContentVertical

		// early out?
		Widget[] children = this.children;
		if (children.empty)
		{
			if (bFitWidth || bFitHeight)
			{
				// resize the layout
				MFVector newSize = size;
				if (bFitWidth)
					newSize.x = padding.x + padding.z;
				if (bFitHeight)
					newSize.y = padding.y + padding.w;
				resize(newSize);
			}
			return;
		}

		if (bFitWidth || bFitHeight)
		{
			// fit to largest child in each dimension
			MFVector fit = MFVector.zero;
			foreach (child; children)
			{
				const(MFVector) cSize = child.sizeWithMargin;

				fit.x = MFMax(fit.x, cSize.x + padding.x + padding.z);
				fit.y = MFMax(fit.y, cSize.y + padding.y + padding.w);
			}

			// resize the layout
			MFVector newSize = size;
			if (bFitWidth)
				newSize.x = fit.x;
			if (bFitHeight)
				newSize.y = fit.y;
			resize(newSize);
		}

		MFVector cPos = MFVector(padding.x, padding.y);
		MFVector cSize = MFVector(size.x - (padding.x + padding.z), size.y - (padding.y + padding.w));

		foreach (child; children)
		{
			MFVector cMargin = child.layoutMargin;
			MFVector size = child.size;
			MFVector tPos = cPos + MFVector(cMargin.x, cMargin.y);
			MFVector tSize = cSize - MFVector(cMargin.x + cMargin.z, cMargin.y + cMargin.w);

			switch (child.layoutJustification) with(Justification)
			{
				case TopLeft:
					child.position(tPos);
					break;
				case TopCenter:
					child.position(tPos + MFVector((tSize.x - size.x) * 0.5f, 0));
					break;
				case TopRight:
					child.position(tPos + MFVector(tSize.x - size.x, 0));
					break;
				case TopFill:
					child.position(tPos);
					resizeChild(child, MFVector(tSize.x, size.y));
					break;
				case CenterLeft:
					child.position(tPos + MFVector(0, (tSize.y - size.y) * 0.5f));
					break;
				case Center:
					child.position(tPos + MFVector((tSize.x - size.x) * 0.5f, (tSize.y - size.y) * 0.5f));
					break;
				case CenterRight:
					child.position(tPos + MFVector(tSize.x - size.x, (tSize.y - size.y) * 0.5f));
					break;
				case CenterFill:
					child.position(tPos + MFVector(0, (tSize.y - size.y) * 0.5f));
					resizeChild(child, MFVector(tSize.x, size.y));
					break;
				case BottomLeft:
					child.position(tPos + MFVector(0, tSize.y - size.y));
					break;
				case BottomCenter:
					child.position(tPos + MFVector((tSize.x - size.x) * 0.5f, tSize.y - size.y));
					break;
				case BottomRight:
					child.position(tPos + MFVector(tSize.x - size.x, tSize.y - size.y));
					break;
				case BottomFill:
					child.position(tPos + MFVector(0, tSize.y - size.y));
					resizeChild(child, MFVector(tSize.x, size.y));
					break;
				case FillLeft:
					child.position(tPos);
					resizeChild(child, MFVector(size.x, tSize.y));
					break;
				case FillCenter:
					child.position(tPos + MFVector((tSize.x - size.x) * 0.5f, 0));
					resizeChild(child, MFVector(size.x, tSize.y));
					break;
				case FillRight:
					child.position(tPos + MFVector(tSize.x - size.x, 0));
					resizeChild(child, MFVector(size.x, tSize.y));
					break;
				case Fill:
					child.position(tPos);
					resizeChild(child, tSize);
					break;
				case None:
					// this widget has absolute coordinates..
				default:
					break;
			}
		}
	}
}
