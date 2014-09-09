module db.ui.stringentrylogic;

import db.tools.stringbuilder;

import fuji.fuji;
import fuji.input;

import std.utf: count;
import std.uni;
import std.algorithm;

bool isNewline(dchar c)
{
	return c == '\n' || c == '\r';
}

bool isAlphaNumeric(dchar c)
{
	return isAlpha(c) || isNumber(c);
}

class StringEntryLogic
{
	alias StringChangeCallback = void delegate(const(char)[]);

	enum StringType
	{
		Unknown = -1,
		Regular = 0,
		MultiLine,
		Numeric,
		Password
	}

	@property final const(char)[] text() const pure nothrow @nogc { return buffer.text; }
	@property final void text(const(char)[] text)
	{
		if(buffer[] == text[])
			return;

		buffer = text.dup;
		if(_maxLen && buffer.length > _maxLen)
			buffer = buffer[0.._maxLen];

		_selectionStart = _selectionEnd = _cursorPos = cast(int)buffer.length;

		if(changeCallback)
			changeCallback(buffer);
	}

	@property final const(char)[] renderText() const pure nothrow @nogc
	{
		if(type == StringType.Password)
		{
			static immutable asterisks = "**************************************************************************************************************";
			size_t numChars = buffer.text.count;
			if(numChars <= asterisks.length)
				return asterisks[0..numChars];
			else
				assert(false, "TODO: password too long, allocate a buffer to hold the asterisks...");
		}
		return buffer;
	}


	@property final void maxLength(int length) pure nothrow @nogc { _maxLen = length; }
	@property final int maxLength() const pure nothrow @nogc { return _maxLen; }

	@property final void type(StringType type) pure nothrow @nogc { _type = type; }
	@property final StringType type() const pure nothrow @nogc { return _type; }

	@property final int cursorPos() const pure nothrow @nogc { return _cursorPos; }
	final void setCursorPos(size_t position, bool bUpdateSelection = false) pure nothrow @nogc
	{
		position = MFClamp(0, position, buffer.text.count);

		_selectionEnd = _cursorPos = cast(int)position;
		if(!bUpdateSelection)
			_selectionStart = cast(int)position;
	}


	final void getSelection(out int selStart, out int selEnd) const pure nothrow @nogc
	{
		selStart = _selectionStart;
		selEnd = _selectionEnd;
	}

	final void setSelection(int start, int end) pure nothrow @nogc
	{
		int len = cast(int)buffer.length;
		start = MFClamp(0, start, len);
		end = MFClamp(0, end, len);

		_selectionStart = start;
		_selectionEnd = end;
		_cursorPos = end;
	}

	final void acceptableCharacters(string chars) pure nothrow @nogc { include = chars; }
	final void excludedCharacters(string chars) pure nothrow @nogc { exclude = chars; }

	static void setRepeatParams(float repeatDelay, float repeatRate) nothrow @nogc { gRepeatDelay = repeatDelay; gRepeatRate = repeatRate; }

	final void setChangeCallback(StringChangeCallback callback) pure nothrow @nogc { changeCallback = callback; }

	final void update()
	{
		bool shiftL = !!MFInput_Read(MFKey.LShift, MFInputDevice.Keyboard);
		bool shiftR = !!MFInput_Read(MFKey.RShift, MFInputDevice.Keyboard);
		bool ctrlL = !!MFInput_Read(MFKey.LControl, MFInputDevice.Keyboard);
		bool ctrlR = !!MFInput_Read(MFKey.RControl, MFInputDevice.Keyboard);

		int keyPressed = 0;

		bool shift = shiftL || shiftR;
		bool ctrl = ctrlL || ctrlR;

		version(Windows)
		{
/+
			if(ctrl && MFInput_WasPressed(MFKey.C, MFInputDevice.Keyboard) && _selectionStart != _selectionEnd)
			{
				MFDisplay *pDisplay = MFDisplay_GetCurrent();
				HWND hWnd = (HWND)MFWindow_GetSystemWindowHandle(MFDisplay_GetDisplaySettings(pDisplay)->pWindow);
				BOOL opened = OpenClipboard(hWnd);

				if(opened)
				{
					int selMin = MFMin(_selectionStart, _selectionEnd);
					int selMax = MFMax(_selectionStart, _selectionEnd);

					int numChars = selMax-selMin;

					HANDLE hData = GlobalAlloc(GMEM_MOVEABLE, numChars + 1);
					char *pString = (char*)GlobalLock(hData);

					MFString_Copy(pString, GetRenderString().SubStr(selMin, numChars).CStr());

					GlobalUnlock(hData);

					EmptyClipboard();
					SetClipboardData(CF_TEXT, hData);

					CloseClipboard();

					return;
				}
			}
			else if(ctrl && MFInput_WasPressed(MFKey.X, MFInputDevice.Keyboard) && _selectionStart != _selectionEnd)
			{
				MFDisplay *pDisplay = MFDisplay_GetCurrent();
				HWND hWnd = (HWND)MFWindow_GetSystemWindowHandle(MFDisplay_GetDisplaySettings(pDisplay)->pWindow);
				BOOL opened = OpenClipboard(hWnd);

				if(opened)
				{
					int selMin = MFMin(_selectionStart, _selectionEnd);
					int selMax = MFMax(_selectionStart, _selectionEnd);

					int numChars = selMax-selMin;

					HANDLE hData = GlobalAlloc(GMEM_MOVEABLE, numChars + 1);
					char *pString = (char*)GlobalLock(hData);

					MFString_Copy(pString, GetRenderString().SubStr(selMin, numChars).CStr());

					GlobalUnlock(hData);

					EmptyClipboard();
					SetClipboardData(CF_TEXT, hData);

					CloseClipboard();

					ClearSelection();
				}

				return;
			}
			else if(ctrl && MFInput_WasPressed(MFKey.V, MFInputDevice.Keyboard))
			{
				MFDisplay *pDisplay = MFDisplay_GetCurrent();
				HWND hWnd = (HWND)MFWindow_GetSystemWindowHandle(MFDisplay_GetDisplaySettings(pDisplay)->pWindow);
				BOOL opened = OpenClipboard(hWnd);

				if(opened)
				{
					int selMin = MFMin(_selectionStart, _selectionEnd);
					int selMax = MFMax(_selectionStart, _selectionEnd);

					int numChars = selMax-selMin;

					HANDLE hData = GetClipboardData(CF_TEXT);
					MFString paste((const char*)GlobalLock(hData), true);

					buffer.Replace(selMin, numChars, paste);

					GlobalUnlock(hData);

					_cursorPos = selMin + paste.NumBytes();
					_selectionStart = _selectionEnd = _cursorPos;

					GlobalUnlock(hData);

					CloseClipboard();

					if((numChars || _cursorPos != selMin) && changeCallback)
						changeCallback(buffer);
				}

				return;
			}
+/
		}

		// check for new keypresses
		foreach(a; 0..255)
		{
			if(MFInput_WasPressed(a, MFInputDevice.Keyboard))
			{
				keyPressed = a;
				_holdKey = a;
				_repeatDelay = gRepeatDelay;
				break;
			}
		}

		// handle repeat keys
		if(_holdKey && MFInput_Read(_holdKey, MFInputDevice.Keyboard))
		{
			_repeatDelay -= MFTimeDelta();
			if(_repeatDelay <= 0)
			{
				keyPressed = _holdKey;
				_repeatDelay += gRepeatRate;
			}
		}
		else
			_holdKey = 0;

		// if there was a new key press
		if(keyPressed)
		{
			switch(keyPressed)
			{
				case MFKey.Backspace:
				case MFKey.Delete:
				{
					if(_selectionStart != _selectionEnd)
					{
						clearSelection();
					}
					else
					{
						if(keyPressed == MFKey.Backspace && _cursorPos > 0)
						{
							buffer.remove(--_cursorPos, 1);
							_selectionStart = _selectionEnd = _cursorPos;

							if(changeCallback)
								changeCallback(buffer);
						}
						else if(keyPressed == MFKey.Delete && _cursorPos < buffer.length)
						{
							buffer.remove(_cursorPos, 1);
							_selectionStart = _selectionEnd = _cursorPos;

							if(changeCallback)
								changeCallback(buffer);
						}
					}
					break;
				}

				case MFKey.Left:
				case MFKey.Right:
				case MFKey.Home:
				case MFKey.End:
				{
					if(ctrl)
					{
						if(keyPressed == MFKey.Left)
						{
							while(_cursorPos && isWhite(buffer[_cursorPos-1]))
								--_cursorPos;
							if(isAlphaNumeric(buffer[_cursorPos-1]))
							{
								while(_cursorPos && isAlphaNumeric(buffer[_cursorPos-1]))
									--_cursorPos;
							}
							else if(_cursorPos)
							{
								--_cursorPos;
								while(_cursorPos && buffer[_cursorPos-1] == buffer[_cursorPos])
									--_cursorPos;
							}
						}
						else if(keyPressed == MFKey.Right)
						{
							while(_cursorPos < buffer.length && isWhite(buffer[_cursorPos]))
								++_cursorPos;
							if(isAlphaNumeric(buffer[_cursorPos]))
							{
								while(_cursorPos < buffer.length && isAlphaNumeric(buffer[_cursorPos]))
									++_cursorPos;
							}
							else if(_cursorPos < buffer.length)
							{
								++_cursorPos;
								while(_cursorPos < buffer.length && buffer[_cursorPos] == buffer[_cursorPos-1])
									++_cursorPos;
							}
						}
						else if(keyPressed == MFKey.Home)
							_cursorPos = 0;
						else if(keyPressed == MFKey.End)
							_cursorPos = cast(int)buffer.length;
					}
					else
					{
						if(keyPressed == MFKey.Left)
							_cursorPos = (!shift && _selectionStart != _selectionEnd ? MFMin(_selectionStart, _selectionEnd) : MFMax(_cursorPos-1, 0));
						else if(keyPressed == MFKey.Right)
							_cursorPos = (!shift && _selectionStart != _selectionEnd ? MFMax(_selectionStart, _selectionEnd) : MFMin(_cursorPos+1, cast(int)buffer.length));
						else if(keyPressed == MFKey.Home)
							_cursorPos = 0;	// TODO: if multiline, go to start of line..
						else if(keyPressed == MFKey.End)
							_cursorPos = cast(int)buffer.length;	// TODO: if multiline, go to end of line...
					}

					if(shift)
						_selectionEnd = _cursorPos;
					else
						_selectionStart = _selectionEnd = _cursorPos;

					break;
				}

				default:
				{
					bool caps = MFInput_GetKeyboardStatusState(MFKeyboardStatusState.CapsLock);
					int ascii = MFInput_KeyToAscii(keyPressed, shift, caps);

					if(ascii && (!_maxLen || buffer.length < _maxLen-1))
					{
						// check character exclusions
						if(isNewline(ascii) && type != StringType.MultiLine)
							break;
						if(ascii == '\t' && type != StringType.MultiLine)
							break;
						if(type == StringType.Numeric && !isNumber(ascii))
							break;
						if(include)
						{
							if(!include.canFind(ascii))
								break;
						}
						if(exclude)
						{
							if(exclude.canFind(ascii))
								break;
						}

						int selMin = MFMin(_selectionStart, _selectionEnd);
						int selMax = MFMax(_selectionStart, _selectionEnd);
						int selRange = selMax - selMin;

						buffer.replace(selMin, selRange, cast(dchar)ascii);
						_cursorPos = selMin + 1;

						_selectionStart = _selectionEnd = _cursorPos;

						if(changeCallback)
							changeCallback(buffer);
					}
					break;
				}
			}
		}
	}

	final void draw() {}

private:
	final void clearSelection()
	{
		if(_selectionStart == _selectionEnd)
			return;

		int selMin = MFMin(_selectionStart, _selectionEnd);
		int selMax = MFMax(_selectionStart, _selectionEnd);

		buffer.remove(selMin, selMax - selMin);

		_cursorPos = selMin;
		_selectionStart = _selectionEnd = _cursorPos;

		if(changeCallback)
			changeCallback(buffer);
	}

	StringBuilder!char buffer;
	string include;
	string exclude;

	int _maxLen;
	int _cursorPos;
	int _selectionStart, _selectionEnd;
	int _holdKey;
	float _repeatDelay;

	StringType _type = StringType.Regular;

	StringChangeCallback changeCallback;

	__gshared float gRepeatDelay = 0.3f;
	__gshared float gRepeatRate = 0.06f;
}
