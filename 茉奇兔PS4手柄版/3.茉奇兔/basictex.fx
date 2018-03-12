#include "lighting.fx"

cbuffer cbPerFrame
{
	DirectionalLight gDirLight;
	PointLight gPointLight;
	SpotLight gSpotLight;
	float3 gEyePosW;

	float4 gFogColor;
	float gFogStart;
	float gFogRange;

};

cbuffer cbPerParticle
{
	float gParticleTime;
	float gParticleRange;
	float gParticleRand;
	float gParticleAlpha;
	float gParticleVel;
	float3 gParticlePos;
};

cbuffer cbPerObject
{
	float4x4 gWorld;
	float4x4 gViewProj;
	float4x4 gWorldInvTranspose;
	float4x4 gWorldViewProj;
	float4x4 gTexTransform;
	Material gMaterial;
};

Texture2D gDiffuseMap;
TextureCube gCubeMap;

SamplerState samAnisotropic
{
	Filter = ANISOTROPIC;
	MaxAnisotropy = 4;

	AddressU = WRAP;
	AddressV = WRAP;
};

//---------------通常obj-vertex in out---------
struct VertexIn
{
	float3 PosL    : POSITION;
	float3 NormalL : NORMAL;
	float2 Tex     : TEXCOORD;
};

struct VertexOut
{
	float4 PosH    : SV_POSITION;
	float3 PosW    : POSITION;
	float3 NormalW : NORMAL;
	float2 Tex     : TEXCOORD;
};
//-----------------------------------------

//---------------gsvertex in out---------
struct GeoVertexIn{

	float3 CenterW : POSITION;
	float4 ColorW  : COLOR;
	float2 SizeW   : SIZE;

};

struct GeoIn
{
	float3 CenterW : POSITION;
	float4 ColorW  : COLOR;
	float2 SizeW   : SIZE;
};

struct GeoOut{

	float4 PosH    : SV_POSITION;
	float3 PosW    : POSITION;
	float3 NormalW : NORMAL;
	float4 ColorW  : COLOR;
	float2 Tex	   : TEXCOORD;
	uint PrimID    : SV_PrimitiveID;

};

//---------------------------------

VertexOut VS(VertexIn vin)
{
	VertexOut vout;

	
	vout.PosW = mul(float4(vin.PosL, 1.0f), gWorld).xyz;
	vout.NormalW = mul(vin.NormalL, (float3x3)gWorldInvTranspose);

	vout.PosH = mul(float4(vin.PosL, 1.0f), gWorldViewProj);

	vout.Tex = mul(float4(vin.Tex, 0.0f, 1.0f), gTexTransform).xy;
	//vout.Tex = vin.Tex;

	return vout;
}

VertexOut VSSky(VertexIn vin)
{
	VertexOut vout;

	vout.PosW = vin.PosL;
	vout.NormalW = mul(vin.NormalL, (float3x3)gWorldInvTranspose);

	vout.PosH = mul(float4(vin.PosL, 1.0f), gWorldViewProj).xyww;

	//vout.Tex = mul(float4(vin.Tex, 0.0f, 1.0f), gTexTransform).xy;
	vout.Tex = vin.Tex;

	return vout;
}

//テクスチャ使用・透過・霧
float4 PS(VertexOut pin, uniform bool gUseTexure, uniform bool gAlphaClip, uniform bool gFogEnabled) : SV_Target
{
	
	// Interpolating normal can unnormalize it, so normalize it.
	pin.NormalW = normalize(pin.NormalW);

	float3 toEyeW = gEyePosW - pin.PosW;
	float distToEye = length(toEyeW);

	toEyeW /= distToEye;

	float4 ambient = float4(0.0f, 0.0f, 0.0f, 0.0f);
	float4 diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
	float4 spec = float4(0.0f, 0.0f, 0.0f, 0.0f);

	float4 A, D, S;

	ComputeDirectionalLight(gMaterial, gDirLight, pin.NormalW, toEyeW, A, D, S);
	ambient += A;
	diffuse += D;
	spec += S;

	ComputePointLight(gMaterial, gPointLight, pin.PosW, pin.NormalW, toEyeW, A, D, S);
	ambient += A;
	diffuse += D;
	spec += S;

	ComputeSpotLight(gMaterial, gSpotLight, pin.PosW, pin.NormalW, toEyeW, A, D, S);
	ambient += A;
	diffuse += D;
	spec += S;
	
	
	float4 texColor = float4(1, 1, 1, 1);
	if (gUseTexure)
	{
		texColor = gDiffuseMap.Sample(samAnisotropic, pin.Tex);
		if (gAlphaClip)
		{
			clip(texColor.a - 0.3f);
		}
	}

	float4 litColor = texColor;

	litColor = texColor*(ambient + diffuse) + spec;

	// Common to take alpha from diffuse material and texture.
	if (gFogEnabled)
	{
		float fogLerp = saturate((distToEye - gFogStart) / gFogRange);

		// Blend the fog color and the lit color.
		litColor = lerp(litColor, gFogColor, fogLerp);
	}

	// Common to take alpha from diffuse material and texture.
	litColor.a = gMaterial.Diffuse.a * texColor.a*0.6f;//アルファチャンネルがないので0.6乗算して透明化する

	return litColor;
}


float4 PSNoAmbient(VertexOut pin, uniform bool gUseTexure, uniform bool gAlphaClip, uniform bool gFogEnabled) : SV_Target
{

	// Interpolating normal can unnormalize it, so normalize it.
	pin.NormalW = normalize(pin.NormalW);

	float3 toEyeW = gEyePosW - pin.PosW;

		float distToEye = length(toEyeW);

	toEyeW /= distToEye;

	float4 ambient = float4(0.0f, 0.0f, 0.0f, 0.0f);
		float4 diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
		float4 spec = float4(0.0f, 0.0f, 0.0f, 0.0f);

		float4 A, D, S;

	ComputeDirectionalLight(gMaterial, gDirLight, pin.NormalW, toEyeW, A, D, S);
	//ambient += A;
	diffuse += D;
	spec += S;

	ComputePointLight(gMaterial, gPointLight, pin.PosW, pin.NormalW, toEyeW, A, D, S);
	ambient += A;
	diffuse += D;
	spec += S;

	ComputeSpotLight(gMaterial, gSpotLight, pin.PosW, pin.NormalW, toEyeW, A, D, S);
	ambient += A;
	diffuse += D;
	spec += S;


	float4 texColor = float4(1, 1, 1, 1);
	if (gUseTexure)
	{
		texColor = gDiffuseMap.Sample(samAnisotropic, pin.Tex);
		if (gAlphaClip)
		{
			clip(texColor.a - 0.3f);
		}
	}

	float4 litColor = texColor;

		litColor = texColor*(ambient + diffuse) + spec;

	// Common to take alpha from diffuse material and texture.
	if (gFogEnabled)
	{
		float fogLerp = saturate((distToEye - gFogStart) / gFogRange);

		// Blend the fog color and the lit color.
		litColor = lerp(litColor, gFogColor, fogLerp);
	}

	// Common to take alpha from diffuse material and texture.
	litColor.a = gMaterial.Diffuse.a * texColor.a*0.6f;//アルファチャンネルがないので0.6乗算して透明化する

	return litColor;
}



float4 PSNoLight(VertexOut pin, uniform bool gUseTexure, uniform bool gAlphaClip, uniform bool gFogEnabled) : SV_Target
{

	// Interpolating normal can unnormalize it, so normalize it.
	pin.NormalW = normalize(pin.NormalW);

	float3 toEyeW = gEyePosW - pin.PosW;

	float distToEye = length(toEyeW);

	toEyeW /= distToEye;

	float4 texColor = float4(1, 1, 1, 1);
	if (gUseTexure)
	{
		texColor = gDiffuseMap.Sample(samAnisotropic, pin.Tex);
		if (gAlphaClip)
		{
			clip(texColor.a - 0.3f);
		}
	}

	float4 litColor = texColor;

	// Common to take alpha from diffuse material and texture.
	if (gFogEnabled)
	{
		float fogLerp = saturate((distToEye - gFogStart) / gFogRange);

		// Blend the fog color and the lit color.
		litColor = lerp(litColor, gFogColor, fogLerp);
	}

	// Common to take alpha from diffuse material and texture.
	litColor.a = gMaterial.Diffuse.a * texColor.a*0.6f;//アルファチャンネルがないので0.6乗算して透明化する

	return litColor;
}


//テクスチャ使用・透過・霧
float4 PSSky(VertexOut pin, uniform bool gUseTexure, uniform bool gAlphaClip, uniform bool gFogEnabled) : SV_Target
{

	// Interpolating normal can unnormalize it, so normalize it.
	pin.NormalW = normalize(pin.NormalW);

	float3 toEyeW = gEyePosW - pin.PosW;

	float distToEye = length(toEyeW);

	toEyeW /= distToEye;

	float4 texColor = float4(1, 1, 1, 1);
	if (gUseTexure)
	{
		texColor = gCubeMap.Sample(samAnisotropic, pin.PosW);
		if (gAlphaClip)
		{
			clip(texColor.a - 0.3f);
		}
	}

	float4 litColor = texColor;

	// Common to take alpha from diffuse material and texture.
	if (gFogEnabled)
	{
		float fogLerp = saturate((distToEye - gFogStart) / gFogRange);

		// Blend the fog color and the lit color.
		litColor = lerp(litColor, gFogColor, fogLerp);
	}

	// Common to take alpha from diffuse material and texture.
	litColor.a = gMaterial.Diffuse.a * texColor.a*0.6f;//アルファチャンネルがないので0.6乗算して透明化する

	return litColor;
}


GeoIn BS(GeoVertexIn input)
{
	GeoIn output;

	output.CenterW = input.CenterW;
	output.SizeW = input.SizeW;
	output.ColorW = input.ColorW;

	return output;
}

GeoIn BSParticle(GeoVertexIn input)
{
	GeoIn output;
	output.CenterW.x = input.CenterW.x + gParticlePos.x;
	output.CenterW.y = input.CenterW.y + gParticlePos.y;
	output.CenterW.z = input.CenterW.z + gParticlePos.z;
	//output.CenterW = input.CenterW;
	output.SizeW = input.SizeW;
	output.ColorW = input.ColorW;

	return output;
}

[maxvertexcount(4)]
void GSParticle(point GeoIn gin[1],
	uint primID : SV_PrimitiveID,
	inout TriangleStream<GeoOut> triStream)
{
	float3 up = float3(0.0f, 1.0f, 0.0f);
	float3 look = gEyePosW - gin[0].CenterW; 
	look.y = 0.0f; 
	look = normalize(look);
	float3 right = cross(up, look);
	
	gin[0].CenterW.x += sin(gParticleTime / 3.0 + gParticleRand) * gParticleRange *0.25;
	gin[0].CenterW.y += tan(gParticleTime / 556.0 + (2.0 + sin(gParticleTime) * 0.01)*gParticleRand) * gParticleRange * 0.25;

	//gin[0].ColorW.x = sin(gParticleTime / 3.0 + gParticleRand)*0.25;

	float halfWidth = 0.5f*gin[0].SizeW.y;
	float halfHeight = 0.5f*gin[0].SizeW.y;

	float4 v[4];
	v[0] = float4(gin[0].CenterW + halfWidth*right - halfHeight*up, 1.0f);
	v[1] = float4(gin[0].CenterW + halfWidth*right + halfHeight*up, 1.0f);
	v[2] = float4(gin[0].CenterW - halfWidth*right - halfHeight*up, 1.0f);
	v[3] = float4(gin[0].CenterW - halfWidth*right + halfHeight*up, 1.0f);

	float2 texC[4];
	texC[0] = float2(0.0f, 1.0f);
	texC[1] = float2(1.0f, 1.0f);
	texC[2] = float2(0.0f, 0.0f);
	texC[3] = float2(1.0f, 0.0f);

	GeoOut gout;
	[unroll]
	for (int i = 0; i < 4; ++i)
	{
		gout.PosH = mul(v[i], gViewProj); 
		gout.PosW = v[i].xyz; 
		gout.NormalW = look;
		gout.ColorW = gin[0].ColorW;
		gout.Tex = texC[i];
		gout.PrimID = primID;

		triStream.Append(gout); 
	}
}

[maxvertexcount(4)]
void GSWing(point GeoIn gin[1],
	uint primID : SV_PrimitiveID,
	inout TriangleStream<GeoOut> triStream)
{

	float3 up = float3(0.0f, 1.0f, 0.0f);
	float3 look = gEyePosW - gin[0].CenterW;
	look.y = 0.0f;
	look = normalize(look);
	float3 right = cross(up, look);


	gin[0].CenterW.x += cos(gParticleTime / 3.0 + gParticleRand) * gParticleRange *0.25;
	gin[0].CenterW.y += tan(gParticleTime / 556.0 + (2.0 + sin(gParticleTime) * 0.01)*gParticleRand) * gParticleRange * 0.25;

	float halfWidth = 0.5f*gin[0].SizeW.y;
	float halfHeight = 0.5f*gin[0].SizeW.y;

	float4 v[4];
	v[0] = float4(gin[0].CenterW + halfWidth*right - halfHeight*up, 1.0f);
	v[1] = float4(gin[0].CenterW + halfWidth*right + halfHeight*up, 1.0f);
	v[2] = float4(gin[0].CenterW - halfWidth*right - halfHeight*up, 1.0f);
	v[3] = float4(gin[0].CenterW - halfWidth*right + halfHeight*up, 1.0f);

	float2 texC[4];
	texC[0] = float2(0.0f, 1.0f);
	texC[1] = float2(1.0f, 1.0f);
	texC[2] = float2(0.0f, 0.0f);
	texC[3] = float2(1.0f, 0.0f);

	GeoOut gout;
	[unroll]
	for (int i = 0; i < 4; ++i)
	{
		gout.PosH = mul(v[i], gViewProj);
		gout.PosW = v[i].xyz;
		gout.NormalW = look;
		gout.ColorW = gin[0].ColorW;
		gout.Tex = texC[i];
		gout.PrimID = primID;

		triStream.Append(gout);
	}
}

[maxvertexcount(4)]
void GSRain(point GeoIn gin[1],
	uint primID : SV_PrimitiveID,
	inout TriangleStream<GeoOut> triStream)
{

	float3 up = float3(0.0f, 1.0f, 0.0f);
	float3 look = gEyePosW - gin[0].CenterW;
	look.y = 0.0f;
	look = normalize(look);
	float3 right = cross(up, look);

	gin[0].CenterW.x -= gParticleTime* 20.0f;
	gin[0].CenterW.y -= gParticleTime*gParticleVel*5.0f;

	//gin[0].CenterW.x += cos(gParticleTime / 3.0 + gParticleRand) * gParticleRange *0.25;
	//gin[0].CenterW.y += sin(gParticleTime / 556.0 + (2.0 + sin(gParticleTime) * 0.01)*gParticleRand) * gParticleRange * 0.25;

	float halfWidth = 0.5f*gin[0].SizeW.y;
	float halfHeight = 0.5f*gin[0].SizeW.y;

	float4 v[4];
	v[0] = float4(gin[0].CenterW + halfWidth*right - halfHeight*up, 1.0f);
	v[1] = float4(gin[0].CenterW + halfWidth*right + halfHeight*up, 1.0f);
	v[2] = float4(gin[0].CenterW - halfWidth*right - halfHeight*up, 1.0f);
	v[3] = float4(gin[0].CenterW - halfWidth*right + halfHeight*up, 1.0f);

	float2 texC[4];
	texC[0] = float2(0.0f, 1.0f);
	texC[1] = float2(1.0f, 1.0f);
	texC[2] = float2(0.0f, 0.0f);
	texC[3] = float2(1.0f, 0.0f);

	GeoOut gout;
	[unroll]
	for (int i = 0; i < 4; ++i)
	{
		gout.PosH = mul(v[i], gViewProj);
		gout.PosW = v[i].xyz;
		gout.NormalW = look;
		gout.ColorW = gin[0].ColorW;
		gout.Tex = texC[i];
		gout.PrimID = primID;

		triStream.Append(gout);
	}
}

[maxvertexcount(4)]
void GSSand(point GeoIn gin[1],
	uint primID : SV_PrimitiveID,
	inout TriangleStream<GeoOut> triStream)
{

	float3 up = float3(0.0f, 1.0f, 0.0f);
	float3 look = gEyePosW - gin[0].CenterW;
	look.y = 0.0f;
	look = normalize(look);
	float3 right = cross(up, look);


	gin[0].CenterW.x += cos(gParticleTime / 3.0 + gParticleRand) * gParticleRange *0.25;
	gin[0].CenterW.y += sin(gParticleTime / 556.0 + (2.0 + sin(gParticleTime) * 0.01)*gParticleRand) * gParticleRange * 0.1;

	float halfWidth = 0.5f*gin[0].SizeW.y;
	float halfHeight = 0.5f*gin[0].SizeW.y;

	float4 v[4];
	v[0] = float4(gin[0].CenterW + halfWidth*right - halfHeight*up, 1.0f);
	v[1] = float4(gin[0].CenterW + halfWidth*right + halfHeight*up, 1.0f);
	v[2] = float4(gin[0].CenterW - halfWidth*right - halfHeight*up, 1.0f);
	v[3] = float4(gin[0].CenterW - halfWidth*right + halfHeight*up, 1.0f);

	float2 texC[4];
	texC[0] = float2(0.0f, 1.0f);
	texC[1] = float2(1.0f, 1.0f);
	texC[2] = float2(0.0f, 0.0f);
	texC[3] = float2(1.0f, 0.0f);

	GeoOut gout;
	[unroll]
	for (int i = 0; i < 4; ++i)
	{
		gout.PosH = mul(v[i], gViewProj);
		gout.PosW = v[i].xyz;
		gout.NormalW = look;
		gout.ColorW = gin[0].ColorW;
		gout.Tex = texC[i];
		gout.PrimID = primID;

		triStream.Append(gout);
	}
}


float3 DiskWithMotionBlur(float3 col, float2 uv, float3 sph, float2 cd, float3 sphcol)
{
	float2 xc = uv - sph.xy;
	float a = dot(cd, cd);
	float b = dot(cd, xc);
	float c = dot(xc, xc) - sph.z*sph.z;
	float h = b*b - a*c;
	if (h>0.0)
	{
		h = sqrt(h);

		float ta = max(0.0, (-b - h) / a);
		float tb = min(1.0, (-b + h) / a);

		if (ta < tb) // we can comment this conditional, in fact
			col = lerp(col, sphcol, clamp(2.0*(tb - ta), 0.0, 1.0));
	}
	return col;
}

float3 hash3(float n) { return frac(sin(float3(n, n + 1.0, n + 2.0))*43758.5453123); }
float4 hash4(float n) { return frac(sin(float4(n, n + 1.0, n + 2.0, n + 3.0))*43758.5453123); }

float2 SetPosition(float time, float4 id )
{
	return float2(0.9*sin((gParticleVel*(0.75 + 0.5*id.z))*time + 20.0*id.x), 0.75*cos(gParticleVel*(0.75 + 0.5*id.w)*time + 20.0*id.y));
}

float2 getVelocity(float time, float4 id) 
{
	return float2(gParticleVel*0.9*cos((gParticleVel*(0.75 + 0.5*id.z))*time + 20.0*id.x), -gParticleVel*0.75*sin(gParticleVel*(0.75 + 0.5*id.w)*time + 20.0*id.y));
}

[maxvertexcount(4)]
void GSAttack(point GeoIn gin[1],
	uint primID : SV_PrimitiveID,
	inout TriangleStream<GeoOut> triStream)
{

	float3 up = float3(0.0f, 1.0f, 0.0f);
	float3 look = gEyePosW - gin[0].CenterW;
	look.y = 0.0f;
	look = normalize(look);
	float3 right = cross(up, look);

	float2 range = float2(gParticleRange, gParticleRange);

	float2 p = (2.0*gin[0].CenterW.xy - range.xy) / gParticleRange;

	float3 col = float3(0.2f, 0.2f + 0.05*p.y, 0.2f);
	float4 off = hash4(gParticleRange*13.13);
	float3 sph = float3(SetPosition(gParticleTime, off), 0.02 + 0.1*off.x);
	float2 cd = getVelocity(gParticleTime, off) / 24.0;
	float3 sphcol = 0.7 + 0.3*sin(3.0*off.z + float3(4.0, 0.0, 2.0));

	//col = DiskWithMotionBlur(col, p, sph, cd, sphcol);

	//col += (1.0 / 255.0)*hash3(p.x + 13.0*p.y);

	gin[0].CenterW.xy = sphcol.xy;

	float halfWidth = 0.5f*gin[0].SizeW.y;
	float halfHeight = 0.5f*gin[0].SizeW.y;

	float4 v[4];
	v[0] = float4(gin[0].CenterW + halfWidth*right - halfHeight*up, 1.0f);
	v[1] = float4(gin[0].CenterW + halfWidth*right + halfHeight*up, 1.0f);
	v[2] = float4(gin[0].CenterW - halfWidth*right - halfHeight*up, 1.0f);
	v[3] = float4(gin[0].CenterW - halfWidth*right + halfHeight*up, 1.0f);

	float2 texC[4];
	texC[0] = float2(0.0f, 1.0f);
	texC[1] = float2(1.0f, 1.0f);
	texC[2] = float2(0.0f, 0.0f);
	texC[3] = float2(1.0f, 0.0f);

	GeoOut gout;
	[unroll]
	for (int i = 0; i < 4; ++i)
	{
		gout.PosH = mul(v[i], gViewProj);
		gout.PosW = v[i].xyz;
		gout.NormalW = look;
		gout.ColorW = gin[0].ColorW;
		gout.Tex = texC[i];
		gout.PrimID = primID;

		triStream.Append(gout);
	}
}


[maxvertexcount(4)]
void GS(point GeoIn gin[1],
	uint primID : SV_PrimitiveID,
	inout TriangleStream<GeoOut> triStream)
{

	float3 up = float3(0.0f, 1.0f, 0.0f);
	float3 look = gEyePosW - gin[0].CenterW;
	look.y = 0.0f;
	look = normalize(look);
	float3 right = cross(up, look);

	float halfWidth = 0.5f*gin[0].SizeW.x;
	float halfHeight = 0.5f*gin[0].SizeW.y;

	float4 v[4];
	v[0] = float4(gin[0].CenterW + halfWidth*right - halfHeight*up, 1.0f);
	v[1] = float4(gin[0].CenterW + halfWidth*right + halfHeight*up, 1.0f);
	v[2] = float4(gin[0].CenterW - halfWidth*right - halfHeight*up, 1.0f);
	v[3] = float4(gin[0].CenterW - halfWidth*right + halfHeight*up, 1.0f);


	float2 texC[4];
	texC[0] = float2(0.0f, 1.0f);
	texC[1] = float2(1.0f, 1.0f);
	texC[2] = float2(0.0f, 0.0f);
	texC[3] = float2(1.0f, 0.0f);


	GeoOut gout;
	[unroll]
	for (int i = 0; i < 4; ++i)
	{
		gout.PosH = mul(v[i], gViewProj);
		gout.PosW = v[i].xyz;
		gout.NormalW = look;
		gout.Tex = texC[i];
		gout.ColorW = gin[0].ColorW;
		gout.PrimID = primID;

		triStream.Append(gout);
	}
}


float4 GSPS(GeoOut pin, uniform bool gUseTexture) : SV_Target
{
	pin.NormalW = normalize(pin.NormalW);

	float3 toEyeW = gEyePosW - pin.PosW;

	float distToEye = length(toEyeW);

	toEyeW /= distToEye;

	float4 ambient = float4(0.0f, 0.0f, 0.0f, 0.0f);
	float4 diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
	float4 spec = float4(0.0f, 0.0f, 0.0f, 0.0f);

	float4 A, D, S;

	ComputeDirectionalLight(gMaterial, gDirLight, pin.NormalW, toEyeW, A, D, S);
	ambient += A;
	diffuse += D;
	spec += S;

	ComputePointLight(gMaterial, gPointLight, pin.PosW, pin.NormalW, toEyeW, A, D, S);
	ambient += A;
	diffuse += D;
	spec += S;

	ComputeSpotLight(gMaterial, gSpotLight, pin.PosW, pin.NormalW, toEyeW, A, D, S);
	ambient += A;
	diffuse += D;
	//spec += S;
	float4 texColor;

	if (gUseTexture){
		texColor = gDiffuseMap.Sample(samAnisotropic, pin.Tex);
		clip(texColor.a - 0.3f);
	}
	else{
		texColor = pin.ColorW;
	}

	float4 litColor = texColor;
	litColor = texColor*(ambient + diffuse) + spec;

	litColor.a = litColor*gParticleAlpha*(sin(gParticleTime / 3.0 + gParticleRand) + 0.2f);

	return litColor;
}

RasterizerState NoCull
{
	CullMode = None;
};

DepthStencilState LessEqualDSS
{
	DepthFunc = LESS_EQUAL;
};

//ライティングなし
technique11 NoLight
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, PSNoLight(true, true, false)));
	}
}

technique11 LightTex
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, PS(true, true, true)));
	}
}

technique11 LightTexNoFog
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, PS(true, true, false)));
	}
}

technique11 Billboard
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, BS()));
		SetGeometryShader(CompileShader(gs_5_0, GS()));
		SetPixelShader(CompileShader(ps_5_0, GSPS(true)));
	}
}

technique11 Rain
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, BSParticle()));
		SetGeometryShader(CompileShader(gs_5_0, GSRain()));
		SetPixelShader(CompileShader(ps_5_0, GSPS(true)));
	}
}

technique11 Particle
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, BSParticle()));
		SetGeometryShader(CompileShader(gs_5_0, GSParticle()));
		SetPixelShader(CompileShader(ps_5_0, GSPS(true)));
	}
}

technique11 Sand
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, BSParticle()));
		SetGeometryShader(CompileShader(gs_5_0, GSSand()));
		SetPixelShader(CompileShader(ps_5_0, GSPS(true)));
	}
}

technique11 Wing
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, BSParticle()));
		SetGeometryShader(CompileShader(gs_5_0, GSWing()));
		SetPixelShader(CompileShader(ps_5_0, GSPS(true)));
	}
}

technique11 AttackParticle
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, BSParticle()));
		SetGeometryShader(CompileShader(gs_5_0, GSAttack()));
		SetPixelShader(CompileShader(ps_5_0, GSPS(true)));
	}
}

technique11 SkyTech
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, VSSky()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, PSSky(true, true, false)));
		SetRasterizerState(NoCull);
		SetDepthStencilState(LessEqualDSS, 0);
	}
}




