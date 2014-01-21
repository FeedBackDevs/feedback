module db.renderer;

public import fuji.types;
public import fuji.view;
public import fuji.render;
public import fuji.renderstate;
public import fuji.vertex;
public import fuji.primitive;
public import fuji.material;
public import fuji.model;
public import fuji.matrix;

public import db.game;


enum RenderLayers
{
	Background,
	Game,
	UI,
	Menu
}

class Renderer
{
	this()
	{
		pDefaultStates = MFStateBlock_CreateDefault();

		// create the renderer with a single layer that clears before rendering
		MFRenderLayerDescription layers[] = [
			MFRenderLayerDescription("background"),
			MFRenderLayerDescription("game"),
			MFRenderLayerDescription("ui"),
			MFRenderLayerDescription("menu")
		];

		pRenderer = MFRenderer_Create(layers, pDefaultStates, null);
		MFRenderer_SetCurrent(pRenderer);

		// background layer will clear the screen...
		MFRenderLayer *pLayer = GetRenderLayer(RenderLayers.Background);
		MFVector clearColour = MFVector(0.0f, 0.0f, 0.2f, 1.0f);
		MFRenderLayer_SetClear(pLayer, MFRenderClearFlags.All, clearColour);

		// game layer needs a clear zbuffer...
		pLayer = GetRenderLayer(RenderLayers.Game);
		MFRenderLayer_SetClear(pLayer, MFRenderClearFlags.DepthStencil);
		MFRenderLayer_SetLayerSortMode(pLayer, MFRenderLayerSortMode.MFRL_SM_None);

		SetCurrentLayer(RenderLayers.Background);
	}

	void Destroy()
	{
		MFRenderer_Destroy(pRenderer);
		MFStateBlock_Destroy(pDefaultStates);
	}

	MFRenderLayer* GetRenderLayer(RenderLayers layer)
	{
		return MFRenderer_GetLayer(pRenderer, layer);
	}

	void SetCurrentLayer(RenderLayers layer)
	{
		MFRenderLayer *pLayer = MFRenderer_GetLayer(pRenderer, layer);

		MFRenderLayerSet layerSet;
		layerSet.pSolidLayer = pLayer;
		MFRenderer_SetRenderLayerSet(pRenderer, &layerSet);
	}

	static @property Renderer Instance() { return Game.Instance.renderer; }

	MFRenderer *pRenderer;
	MFStateBlock *pDefaultStates;
}
