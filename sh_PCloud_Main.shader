Shader "ParticleCloud/Main_Pass"
{
Properties
{
	[NoScaleOffset]
	_Buffer ("Buffer", 2D) = "gray" {}
	[Toggle] _Rst ("Reset", Float) = 0
	_Drag   ("Drag",  Range( 0.0,  3.0)) = 0.5
	_Nstr   ("Noise", Range( 0.0,  1.0)) = 0.5
	[Header(Manipulation force)]
	_Str    ("Strength", Range(-5.0, 5.0)) = 1.0000
	_Fdecay_l ("Decay: linear", Range( 0.0,  1.0)) = 0.15
	_Fdecay_q ("Decay: quadratic", Range( 0.0,  1.0)) = 0.25
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

		Texture2D<float4> _Buffer;
		float4 _Buffer_TexelSize;

		uniform float _Rst;
		uniform float _Str;
		uniform float _Drag;
		uniform float _Nstr;
		uniform float _Fdecay_l;
		uniform float _Fdecay_q;

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
			o.uv  = ComputeScreenPos(o.pos);
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

			uint isvelo = ((uint)i.pos.x)%2;
			//if (_Rst) return float4(0.5,0.5,0.5,1); // World origin
			if (_Rst) // Plane around right hand
			{
				static const float WIDTH = 2;
				if (isvelo) // a bit of velocity for angle-based color mode
					return EncodeColor(float4(-0.001,0.001,0,0));
				else
					return EncodeColor(float4(manips[0].x+i.uv.x*WIDTH-WIDTH/2, manips[0].y,
							manips[0].z+i.uv.y*WIDTH-WIDTH/2, 0));
			}

			if (isvelo) // Velocity
			{
				float4 last_velo  = ReadBuff(i.pos.xyz);
				float4 last_pos   = ReadBuff(int3(i.pos.x-1, i.pos.y, 0));
				float dist = distance(last_pos.xyz, manips[0].xyz);
				if (dist > RESET_DIST)
					return EncodeColor(float4(0,0,0,0)); // Reset to 0 velocity
				return EncodeColor(Compute_Velo(_Drag, fdecay, _Nstr, manips, i.uv.xy, last_velo, last_pos));
			}
			else // Position
			{
				float4 last_pos   = ReadBuff(i.pos.xyz);
				float4 last_velo  = ReadBuff(int3(i.pos.x+1, i.pos.y, 0));
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