module db.main;

import core.runtime;

import fuji.system;
import fuji.display;

import db.game;

version(Windows)
{
	import core.sys.windows.windows;
	extern (Windows) int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
	{
	    int result;

	    try
	    {
			Game game = Game.Instance;

			game.initParams.hInstance = hInstance;
			game.initParams.pCommandLine = lpCmdLine;

			result = Start();
	    }
	    catch (Throwable o)		// catch any uncaught exceptions
	    {
	        MessageBoxA(null, cast(char *)o.toString(), "Error", MB_OK | MB_ICONEXCLAMATION);
	        result = 0;		// failed
	    }

	    return result;
	}
}
else
{
	int main(string args[])
	{
	    int result;

	    try
	    {
			Game game = Game.Instance;

//			game.initParams.argc = cast(int)args.length;
//			game.initParams.argv = ...we have a problem! (not important for now)

			result = Start();
	    }
	    catch (Throwable o)		// catch any uncaught exceptions
	    {
	        result = 0;		// failed
	    }

	    return result;
	}
}

int Start()
{
	MFRect failure;
	MFDisplay_GetNativeRes(&failure);

	Game game = Game.Instance;

	game.initParams.hideSystemInfo = false;

//	game.initParams.display.displayRect.width = failure.width;
//	game.initParams.display.displayRect.height = failure.height;
//	game.initParams.display.bFullscreen = true;
	game.initParams.pAppTitle = "FeedBack".ptr;

	MFSystem_RegisterSystemCallback(MFCallback.FileSystemInit, &Game.Static_InitFileSystem);
	MFSystem_RegisterSystemCallback(MFCallback.InitDone, &Game.Static_Init);
	MFSystem_RegisterSystemCallback(MFCallback.Deinit, &Game.Static_Deinit);
	MFSystem_RegisterSystemCallback(MFCallback.Update, &Game.Static_Update);
	MFSystem_RegisterSystemCallback(MFCallback.Draw, &Game.Static_Draw);

	return MFMain(game.initParams);
}
