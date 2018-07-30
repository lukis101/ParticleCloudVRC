#ifndef PFIELD_UTIL
#define PFIELD_UTIL

#include "noiseSimplex.cginc"

#define SCALE 300.0 // Word coordinate range
#define CAMCLIP -0.00390625f // special(non-approximated) camera near clip value

float pos2color(float p)
{
	//return 0.5 + p/SCALE;
	return 0.5 + clamp(p,-SCALE,SCALE)/SCALE;
}
float color2pos(float c)
{
	return (c-0.5)*SCALE;
}

float4 DecodeColor(float4 col)
{
	float4 o;
	o[0] = color2pos(col[0]);
	o[1] = color2pos(col[1]);
	o[2] = color2pos(col[2]);
	o[3] = color2pos(col[3]);
	return o;
}
float4 EncodeColor(float4 part)
{
	float4 o;
	o[0] = pos2color(part[0]);
	o[1] = pos2color(part[1]);
	o[2] = pos2color(part[2]);
	o[3] = pos2color(part[3]);
	return o;
}

float3 HUEtoRGB(in float H)
{
	float R = abs(H * 6 - 3) - 1;
	float G = 2 - abs(H * 6 - 2);
	float B = 2 - abs(H * 6 - 4);
	return saturate(float3(R,G,B));
}

float4 Compute_Velo(
	in float  Drag,
	in float2 fdecay,
	in float  noise_scale,
	in float4 manips[2], // xyz=pos, w=strength
	in float2 uv,
	in float4 last_velo,
	in float4 last_pos)
{
	// TODO: use 2D noise by translating coords with time
	float noi = 1.0 + snoise(float3(uv*4, _Time[1]/2))*noise_scale;

	float3 force = float3(0,0,0);
	for (uint i=0; i<2; i++)
	{
		float dist = distance(last_pos.xyz, manips[i].xyz);
		float frc = fdecay[0]*dist + fdecay[1]*dist*dist;
		force += (manips[i].xyz-last_pos.xyz)*noi*manips[i].w/frc;
	}

	float4 next_velo;
	next_velo.x = last_velo.x + (force.x - last_velo.x*Drag)*unity_DeltaTime;
	next_velo.y = last_velo.y + (force.y - last_velo.y*Drag)*unity_DeltaTime;
	next_velo.z = last_velo.z + (force.z - last_velo.z*Drag)*unity_DeltaTime;
	next_velo.w = last_velo.w; // UNUSED
	return next_velo;
}

float4 Compute_Pos(
	in  float4 last_velo,
	in  float4 last_pos)
{
	const float SHIFT_SPEED = 0.25;
	// TODO: calc current velocity and average with previous for more precise simulation
	float4 next_pos;
	next_pos.x = last_pos.x + last_velo.x*unity_DeltaTime;
	next_pos.y = last_pos.y + last_velo.y*unity_DeltaTime;
	next_pos.z = last_pos.z + last_velo.z*unity_DeltaTime;
	next_pos.w = last_pos.w + SHIFT_SPEED*unity_DeltaTime; // UNUSED, TODO: shift hue based on velocity/force?
	return next_pos;
}

#endif // PFIELD_UTIL
