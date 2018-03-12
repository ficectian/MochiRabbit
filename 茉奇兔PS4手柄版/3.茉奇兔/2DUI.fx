#include "lighting.fx"

cbuffer cbPerObject
{
	float4x4 gWorldViewProj;

};

Texture2D gDiffuseMap;

SamplerState samAnisotropic
{
	Filter = ANISOTROPIC;
	MaxAnisotropy = 4;

	AddressU = WRAP;
	AddressV = WRAP;
};

struct VertexIn
{
	float3 PosL    : POSITION;
	float2 Tex     : TEXCOORD;
};

struct VertexOut
{
	float4 PosH    : SV_POSITION;
	float3 PosW    : POSITION;
	float2 Tex     : TEXCOORD;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout;

	vout.PosW = vin.PosL;
	vout.Tex = vin.Tex;

	vout.PosH = float4(vin.PosL, 1.0f);

	return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
	float4 color = gDiffuseMap.Sample(samAnisotropic, pin.Tex);
	clip(color.a - 0.3f);
	return color;
}

DepthStencilState DisableDepth
{
	DepthEnable = false;
};

technique11 UITech{

	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, PS()));
		SetDepthStencilState(DisableDepth, 0);
	}

};
