module db.game;

import fuji.fuji;
import fuji.system;
import fuji.filesystem;
import fuji.fs.native;

import fuji.render;
import fuji.renderstate;
import fuji.material;
import fuji.primitive;
import fuji.view;
import fuji.matrix;


class Game
{
	void InitFileSystem()
	{
		MFFileSystemHandle hNative = MFFileSystem_GetInternalFileSystemHandle(MFFileSystemHandles.NativeFileSystem);
		MFMountDataNative mountData;
		mountData.priority = MFMountPriority.Normal;
		mountData.flags = MFMountFlags.FlattenDirectoryStructure | MFMountFlags.Recursive;
		mountData.pMountpoint = "data";
		mountData.pPath = MFFile_SystemPath("data/");
		MFFileSystem_Mount(hNative, mountData);

		mountData.flags = MFMountFlags.DontCacheTOC;
		mountData.pMountpoint = "cache";
		mountData.pPath = MFFile_SystemPath("data/cache");
		MFFileSystem_Mount(hNative, mountData);
	}

	void Init()
	{
		pDefaultStates = MFStateBlock_CreateDefault();

		// create the renderer with a single layer that clears before rendering
		MFRenderLayerDescription layers[] = [ MFRenderLayerDescription("Scene".ptr) ];
		pRenderer = MFRenderer_Create(layers, pDefaultStates, null);
		MFRenderer_SetCurrent(pRenderer);

		MFRenderLayer *pLayer = MFRenderer_GetLayer(pRenderer, 0);
		MFVector clearColour = MFVector(0.0f, 0.0f, 0.2f, 1.0f);
		MFRenderLayer_SetClear(pLayer, MFRenderClearFlags.All, clearColour);

		MFRenderLayerSet layerSet;
		layerSet.pSolidLayer = pLayer;
		MFRenderer_SetRenderLayerSet(pRenderer, &layerSet);
	}

	void Deinit()
	{
		MFRenderer_Destroy(pRenderer);
		MFStateBlock_Destroy(pDefaultStates);
	}

	void Update()
	{
	}

	void Draw()
	{
	}

	MFInitParams initParams;

	///
	static @property Game Instance() { if(instance is null) instance = new Game; return instance; }

	static extern (C) void Static_InitFileSystem()
	{
		instance.InitFileSystem();
	}

	static extern (C) void Static_Init()
	{
		instance.Init();
	}

	static extern (C) void Static_Deinit()
	{
		instance.Deinit();
		instance = null;
	}

	static extern (C) void Static_Update()
	{
		instance.Update();
	}

	static extern (C) void Static_Draw()
	{
		instance.Draw();
	}

private:
	__gshared Game instance;
	__gshared MFRenderer *pRenderer = null;
	__gshared MFStateBlock *pDefaultStates = null;
}
