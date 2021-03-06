module db.main;

import core.runtime;

import fuji.fuji;
import fuji.system;
import fuji.display;

import db.game;

version(Windows)
{
	// HACK: Linking against dynamic MSCRT seems to lost a symbol?!
	extern(C) __gshared const(double) __imp__HUGE = double.infinity;

	import core.sys.windows.windows;
	extern (Windows) int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
	{
		int result;

		try
		{
			Runtime.initialize();

			Game game = Game.instance;

			game.initParams.hInstance = hInstance;
			game.initParams.pCommandLine = lpCmdLine;

			gDefaults.plugin.renderPlugin = game.settings.videoDriver;
			gDefaults.plugin.soundPlugin = game.settings.audioDriver;

			gDefaults.input.useXInput = false;

			result = Start();

			Runtime.terminate();
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
	int main(string[] args)
	{
		int result;

		try
		{
			Game game = Game.instance;

			const(char)*[] argv;
			foreach (arg; args)
				argv ~= arg.ptr;

			game.initParams.argc = cast(int)args.length;
			game.initParams.argv = argv.ptr;

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
	gDefaults.midi.useMidi = true;

	Game game = Game.instance;

	game.initParams.hideSystemInfo = false;

//	MFRect failure;
//	MFDisplay_GetNativeRes(&failure);
//	game.initParams.display.displayRect.width = failure.width;
//	game.initParams.display.displayRect.height = failure.height;
//	game.initParams.display.bFullscreen = true;
	game.initParams.pAppTitle = "FeedBack".ptr;

	Fuji_CreateEngineInstance();

	game.registerCallbacks();

	int r = MFMain(game.initParams);

	Fuji_DestroyEngineInstance();

	return r;
}
