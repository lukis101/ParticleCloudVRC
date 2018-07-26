Shader "ParticleCloud/Main_Pass"
{
Properties
{
	[NoScaleOffset]
	_Buffer ("Buffer", 2D) = "gray" {}
	_Rst    ("Reset", Int) = 0
	_Str    ("Strength", Range(-5.0, 5.0)) = 1.0000
	_Drag   ("Drag",  Range( 0.0,  3.0)) = 0.5
	_Nstr   ("Noise", Range( 0.0,  1.0)) = 0.5
	_Fdecay_l ("Force decay: linear", Range( 0.0,  1.0)) = 0.15
	_Fdecay_q ("Force decay: quadratic", Range( 0.0,  1.0)) = 0.25
}
SubShader
{
	Tags { "Queue"="Overlay+1000" "IgnoreProjector"="True" "RenderType"="Overlay" "PreviewType"="Plane" "DisableBatching"="True" }
	Blend Off
	//Cull Off
	ZWrite Off
	//ZTest Always
	ColorMask RGBA

	Pass
	{
		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		#pragma target 4.6

		#include "UnityCG.cginc"
		#include "PCloud_Util.cginc"

		// Reset particles to manipulator when too far
		#define RESET_DIST 6
		// Resolution(height) of state buffer texture
		#define RESOLUTION 256

		Texture2D<float4> _Buffer;

		int   _Rst;
		int   _Stage;
		float _Str;
		float _Drag;
		float _Nstr;
		float _Fdecay_l;
		float _Fdecay_q;

		struct fs_in
		{
			float4 pos : SV_Position; // in pixels
			float4 uv  : TEXCOORD0;   // 0.0 to 1.0
		};

		//--- Vertex shader ---//
		fs_in vert(float4 vertex : POSITION)
		{
			// TODO place vertices at camera near clip
			// TODO 2 examine camera(clip?) to identify render target and hide
			// if its not the target,so its not rendered for players and etc
			fs_in o;
			o.pos = UnityObjectToClipPos(vertex);
			o.uv  = ComputeScreenPos(UnityObjectToClipPos(vertex));
			return o;
		}

		#define ReadBuff(coords) DecodeColor(_Buffer.Load(coords))

		//--- Fragment shader ---//
		float4 frag (fs_in i) : SV_Target
		{
			float2 fdecay = float2(_Fdecay_l, _Fdecay_q);
			float4 manips[2];
			manips[0] = float4(_WorldSpaceCameraPos, _Str); // main camera
			manips[1] = ReadBuff(int3(0,0,0)); // buffer camera

			//if (_Rst) return float4(0.5,0.5,0.5,1); // World origin
			if (_Rst) // Plane around right hand
			{
				const float WIDTH = 2;
				if (i.uv.x < 0.5)
					return EncodeColor(float4(manips[0].x+i.uv.x*WIDTH*2-WIDTH/2,
							manips[0].y+i.uv.y*WIDTH-WIDTH/2, manips[0].z, 0));
				else // no velocity
					return EncodeColor(float4(0,0,0,0));
			}

			// TODO: interleave pos+velocity: data locality and no need to use resolution constant
			if (i.uv.x >= 0.5) // Velocity
			{
				float4 last_velo  = ReadBuff(i.pos.xyz);
				float4 last_pos   = ReadBuff(int3(i.pos.x-RESOLUTION, i.pos.y, i.pos.z));
				float dist = distance(last_pos.xyz, manips[0].xyz);
				if (dist > RESET_DIST)
					return EncodeColor(float4(0,0,0,0)); // Reset to 0 velocity
				return EncodeColor(Compute_Velo(_Drag, fdecay, _Nstr, manips, i.uv.xy, last_velo, last_pos));
			}
			else // Position
			{
				float4 last_pos   = ReadBuff(i.pos.xyz);
				float4 last_velo  = ReadBuff(int3(i.pos.x+RESOLUTION, i.pos.y, i.pos.z));
				float dist = distance(last_pos.xyz, manips[0].xyz);
				if (dist > RESET_DIST)
					return EncodeColor(float4(manips[0].xyz, 0)); // Reset pos
				return EncodeColor(Compute_Pos(last_velo, last_pos));
			}
			//discard;
			//return 0;
		}
		ENDCG
	}
}
}