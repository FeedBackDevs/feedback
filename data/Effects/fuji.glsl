// fuji matrices
uniform mat4 mWorld;
uniform mat4 mCamera;
uniform mat4 mProjection;
uniform mat4 mShadowMap;
uniform mat4 mFuji0;
uniform mat4 mFuji1;
uniform mat4 mUser0;
uniform mat4 mUser1;
uniform mat4 mUser2;
uniform mat4 mUser3;
uniform mat4 mUV0;
uniform mat4 mUV1;
uniform mat4 mUV2;
uniform mat4 mUV3;
uniform mat4 mView;
uniform mat4 mWorldView;
uniform mat4 mViewProjection;
uniform mat4 mWorldViewProjection;
uniform mat4 mInverseWorld;
uniform mat4 mInverseViewProjection;

// fuji vectors
uniform vec4 vTime;
uniform vec4 vFogColour;
uniform vec4 vFogParams1;
uniform vec4 vFogParams2;
uniform vec4 vRenderState;
uniform vec4 vMaterialDiffuseColour;
uniform vec4 vDiffuseColour;
uniform vec4 vAmbientColour;
uniform vec4 vFuji0;
uniform vec4 vFuji1;
uniform vec4 vFuji2;
uniform vec4 vFuji3;
uniform vec4 vFuji4;
uniform vec4 vFuji5;
uniform vec4 vFuji6;
uniform vec4 vLightCounts;
uniform vec4 vUser0;
uniform vec4 vUser1;
uniform vec4 vUser2;
uniform vec4 vUser3;
uniform vec4 vUser4;
uniform vec4 vUser5;
uniform vec4 vUser6;
uniform vec4 vUser7;
uniform vec4 vUser8;
uniform vec4 vUser9;
uniform vec4 vUser10;
uniform vec4 vUser11;
uniform vec4 vUser12;
uniform vec4 vUser13;
uniform vec4 vUser14;
uniform vec4 vUser15;

uniform vec4 mAnimationMatrices[48*3];

// integer values
uniform ivec4 iLightCounts;
uniform ivec4 iAnimationParams;

// fuji uniform bools
uniform bool bAnimated;
uniform bool bZPrime;
uniform bool bShadowGeneration;
uniform bool bShadowReceiving;
uniform bool bOpaque;
uniform bool bAlphaTest;
uniform bool bFuji0;
uniform bool bFuji1;
uniform bool bFuji2;
uniform bool bUser0;
uniform bool bUser1;
uniform bool bUser2;
uniform bool bUser3;
uniform bool bDiffuseSet;
uniform bool bNormalMapSet;
uniform bool bSpecularMapSet;
uniform bool bDetailMapSet;
uniform bool bOpacityMapSet;
uniform bool bEnvironmentMapSet;
uniform bool bSpecularPowerMapSet;
uniform bool bEmissiveMapSet;
uniform bool bLightMapSet;
uniform bool bShadowBufferSet;
uniform bool bProjectionSet;
uniform bool bUserTex0Set;
uniform bool bUserTex1Set;
uniform bool bUserTex2Set;
uniform bool bUserTex3Set;
uniform bool bUserTex4Set;
uniform bool bVertexTex0Set;
uniform bool bVertexTex1Set;
uniform bool bVertexTex2Set;

// fuji samplers
uniform sampler2D sDiffuseSampler;
uniform sampler2D sNormalSampler;
uniform sampler2D sSpecularSampler;
uniform sampler2D sDetailSampler;
uniform sampler2D sOpacitySampler;
uniform sampler2D sEnvironmentSampler;
uniform sampler2D sSpecularPowerSampler;
uniform sampler2D sEmissiveSampler;
uniform sampler2D sLightSampler;
uniform sampler2D sShadowBufferSampler;
uniform sampler2D sProjectionSampler;
uniform sampler2D sUser0Sampler;
uniform sampler2D sUser1Sampler;
uniform sampler2D sUser2Sampler;
uniform sampler2D sUser3Sampler;
uniform sampler2D sUser4Sampler;
//uniform sampler2D sVertex0Sampler;
//uniform sampler2D sVertex1Sampler;
//uniform sampler2D sVertex2Sampler;

struct StaticInput
{
	vec4 pos;
	vec3 norm;
	vec4 uv;
	vec4 colour;
};

struct AnimatedInput
{
	vec4 pos;
	vec3 norm;
	vec4 uv;
	vec4 colour;
	vec4 weights;
	vec4 indices;
};

struct VSOutput
{
	vec4 pos;
	vec4 colour;
	vec2 uv;
};


vec4 animate(vec4 pos, ivec4 indices, vec4 weights, int numWeights)
{
//	indices *= 3;

	vec4 newPos = pos;
	if(numWeights > 0)
	{
		int i = indices.x;
		vec3 t;
		t.x = dot(pos, mAnimationMatrices[i]);
		t.y = dot(pos, mAnimationMatrices[i+1]);
		t.z = dot(pos, mAnimationMatrices[i+2]);
		newPos.xyz = t*weights.x;
	}
	if(numWeights > 1)
	{
		int i = indices.y;
		vec3 t;
		t.x = dot(pos, mAnimationMatrices[i]);
		t.y = dot(pos, mAnimationMatrices[i+1]);
		t.z = dot(pos, mAnimationMatrices[i+2]);
		newPos.xyz += t*weights.y;
	}
	if(numWeights > 2)
	{
		int i = indices.z;
		vec3 t;
		t.x = dot(pos, mAnimationMatrices[i]);
		t.y = dot(pos, mAnimationMatrices[i+1]);
		t.z = dot(pos, mAnimationMatrices[i+2]);
		newPos.xyz += t*weights.z;
	}
	if(numWeights > 3)
	{
		int i = indices.w;
		vec3 t;
		t.x = dot(pos, mAnimationMatrices[i]);
		t.y = dot(pos, mAnimationMatrices[i+1]);
		t.z = dot(pos, mAnimationMatrices[i+2]);
		newPos.xyz += t*weights.w;
	}

	return newPos;
}

vec2 transformUV(vec4 uv, int uvMatrix)
{
	uvMatrix *= 2;

	vec2 t;
	if(uvMatrix == 0)
	{
		t.x = dot(uv, mUV0._m00_m10_m20_m30); // TODO: look into why the matrices are sideways...
		t.y = dot(uv, mUV0._m01_m11_m21_m31);
	}
	else if(uvMatrix == 1)
	{
		t.x = dot(uv, mUV1._m00_m10_m20_m30);
		t.y = dot(uv, mUV1._m01_m11_m21_m31);
	}
	else if(uvMatrix == 2)
	{
		t.x = dot(uv, mUV2._m00_m10_m20_m30);
		t.y = dot(uv, mUV2._m01_m11_m21_m31);
	}
	else if(uvMatrix == 3)
	{
		t.x = dot(uv, mUV3._m00_m10_m20_m30);
		t.y = dot(uv, mUV3._m01_m11_m21_m31);
	}
	return t;
}
