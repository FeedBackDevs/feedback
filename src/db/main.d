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
			rt_init();
//	        Runtime.initialize();

	        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);

			rt_term();
//	        Runtime.terminate();
	    }
	    catch (Throwable o)		// catch any uncaught exceptions
	    {
	        MessageBoxA(null, cast(char *)o.toString(), "Error", MB_OK | MB_ICONEXCLAMATION);
	        result = 0;		// failed
	    }

	    return result;
	}

	int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
	{
		/* ... insert user code here ... */
//		throw new Exception("not implemented");

		Game game = Game.Instance;

		game.initParams.hInstance = hInstance;
		game.initParams.pCommandLine = lpCmdLine;

		return Start();
	}
}
else
{
	int main(string args[])
	{
	    int result;

	    try
	    {
			rt_init();
//	        Runtime.initialize();

	        result = myMain(args);

			rt_term();
//	        Runtime.terminate();
	    }
	    catch (Throwable o)		// catch any uncaught exceptions
	    {
	        result = 0;		// failed
	    }

	    return result;
	}

	int myMain(string args[])
	{
		/* ... insert user code here ... */
//		throw new Exception("not implemented");

		Game game = Game.Instance;

//		game.initParams.pCommandLine = lpCmdLine;

		return Start();
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
