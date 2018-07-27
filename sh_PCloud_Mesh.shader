Shader "ParticleCloud/Mesh"
{
Properties
{
	[NoScaleOffset]
	_Buffer   ("Particle buffer", 2D)  = "gray" {}
	[NoScaleOffset] // TODO: support this
	_MainTex  ("Particle texture", 2D) = "white" {}
	_Size     ("Size", Range(0., 1.)) = 0.3
	[Header(Mesh and texture setup)]
	[IntRange] _Segments ("Mesh divisions", Range(1, 32)) = 1
	[IntRange] _Factor   ("Subdivisions",   Range(1, 64)) = 4
	[Header(Particle colors)]
	[KeywordEnum(Angle, Static)]
	_ColMode    ("Color mode",   Float) = 0
	_SColor     ("Static Color", Color) = (1.,1.,1.,1.)
	_Brightness ("Brightness",   Range(0., 1.7)) = 1.0
}
SubShader
{
	Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "DisableBatching"="True" /*"PreviewType"="Plane"*/ }
	Blend SrcAlpha One //OneMinusSrcAlpha
	Cull Off
	ZWrite Off
	//ZTest Always
	ColorMask RGBA

	Pass
	{
		CGPROGRAM
		#pragma target 4.6
		#pragma vertex tessvert
		#pragma hull hull
		#pragma domain doma
		#pragma geometry geom
		#pragma fragment frag
		#pragma multi_compile _COLMODE_ANGLE _COLMODE_STATIC

		#include "UnityCG.cginc"
		#include "PCloud_Util.cginc"

		Texture2D<float4> _Buffer;
		Texture2D     _MainTex;
		SamplerState  sampler_MainTex;
		uniform float _Size;
		uniform float _Segments;
		uniform float _Factor;
		uniform float _Brightness;
		uniform float4 _SColor;

		struct vs_in
		{
			float4 pos  : POSITION;
			float4 uv   : TEXCOORD0;
			//float4 col  : COLOR;
		};
		struct tess_in
		{
			float4 pos     : INTERNALTESSPOS;
			float4 uv      : TEXCOORD0;
			//float4 col     : COLOR;
		};
		struct gs_in
		{
			float4 pos     : SV_Position;
			float4 uv      : TEXCOORD0;
			//float4 col     : COLOR;
		};
		struct fs_in
		{
			float4 pos : SV_Position;
			float4 uv  : TEXCOORD0;
			nointerpolation float4 col : COLOR;
		};

		struct PatchConstData
		{
			float edges[4]  : SV_TessFactor;
			float inside[2] : SV_InsideTessFactor;
		};

		//--- Vertex shader ---//
		tess_in tessvert(vs_in v)
		{
			tess_in p;
			p.pos = v.pos;
			p.uv  = v.uv;
			//p.col = v.uv;
			return p;
		}

		PatchConstData PatchConstFunc(InputPatch<tess_in, 4> patch)
		{
			PatchConstData o;
			o.edges[0] = o.edges[1] = o.edges[2] = o.edges[3] = _Factor;
			o.inside[0] = o.inside[1] = _Factor;
			return o;
		}

		//--- Hull shader ---//
		[UNITY_domain("quad")]
		[UNITY_outputtopology("triangle_cw")]
		[UNITY_partitioning("integer")]
		[UNITY_outputcontrolpoints(4)]
		[UNITY_patchconstantfunc("PatchConstFunc")]
		tess_in hull(
			InputPatch<tess_in, 4> patch,
			uint id : SV_OutputControlPointID)
		{
			return patch[id];
		}
		
		//--- Domain shader ---//
		[UNITY_domain("quad")]
		gs_in doma(
			PatchConstData patchdata,
			const OutputPatch<tess_in, 4> patch,
			float2 uv : SV_DomainLocation)
		{
			gs_in data;
			#define DOMAIN_INTERPOLATE(member) data.member = \
				lerp(lerp(patch[0].member, patch[1].member, uv.x), \
					 lerp(patch[3].member, patch[2].member, uv.x), uv.y);

			DOMAIN_INTERPOLATE(pos)
			DOMAIN_INTERPOLATE(uv)
			return data;
		}

		//--- Geometry shader ---//
		[maxvertexcount(3)]
		void geom(triangle gs_in tri[3], inout TriangleStream<fs_in> tristream)
		{
			fs_in o;

			// TODO: optimize upper/lower half detection
			float2 uv_min   = min(min(tri[0].uv.xy, tri[1].uv.xy), tri[2].uv.xy);
			float2 uv_max_y = max(max(tri[0].uv.y,  tri[1].uv.y),  tri[2].uv.y);
			//float xcent = (uv_min.x + uv_max.x)/2;
			float ycent = (uv_min.y + uv_max_y)/2;
			float yavg = (tri[0].uv.y+tri[1].uv.y+tri[2].uv.y)/3;
			if (ycent < yavg) return; // discard lower quad half
			
			uint resolution = _Segments*_Factor;
			float pixsize = 1.0/resolution;
			uint nx = uv_min.x/pixsize;  // pixel x coord
			uint ny = uv_min.y/pixsize;  // pixel y coord
			//uint pid = ny*resolution+nx; // particle index/id
			
			float4 state_pos = DecodeColor(_Buffer.Load(int3(nx,ny,0)));
			float4 state_vel = DecodeColor(_Buffer.Load(int3(nx+resolution,ny,0)));
			float3 wpos = state_pos.xyz;
			
			// Coloring
		#ifdef _COLMODE_ANGLE
			static const float PI = 3.14159265f;
			float angle_xy = (atan2(state_vel.x, state_vel.z)+PI)/(2*PI);
			float angle_yz = (atan2(state_vel.y, state_vel.z)+PI)/(2*PI);
			float angsum = angle_xy+angle_yz;
			if (angsum > 1.0) angsum -= 1.0;
			o.col = float4(HUEtoRGB(angsum), 1);
			// (Optional)Reduce color strengh - lessens saturation from additive blending with high particle density
			o.col = normalize(o.col); // Should probably do simple mult for performance...
		#elif _COLMODE_STATIC
			o.col = _SColor;
		#endif

			// Generate billboard triangle
			float3 right = UNITY_MATRIX_V._m00_m01_m02;
			float3 up    = UNITY_MATRIX_V._m10_m11_m12;
			float  halfS = _Size*0.01;
			float  dist = distance(wpos,_WorldSpaceCameraPos);
			if (dist < 1) // reduce size to prevent filling screen (fillrate bottleneck)
			{
				right *= dist;
				up *= dist;
			}
			
			float4 vert;
			vert  = float4(wpos + halfS * right - halfS * up, 1.0f); // Left
			o.uv  = float4(0.9,0.1,0,1);
			o.pos = UnityObjectToClipPos(mul(unity_WorldToObject, vert));
			tristream.Append(o);

			vert = float4(wpos + halfS * up                , 1.0f); // Top
			o.uv  = float4(0.5,1,0,1);
			o.pos = UnityObjectToClipPos(mul(unity_WorldToObject, vert));
			tristream.Append(o);

			vert = float4(wpos - halfS * right - halfS * up, 1.0f); // Right
			o.uv  = float4(0.1,0.1,0,1);
			o.pos = UnityObjectToClipPos(mul(unity_WorldToObject, vert));
			tristream.Append(o);
		}

		//--- Fragment shader ---//
		fixed4 frag (fs_in i) : SV_Target
		{
			fixed4 tex = _MainTex.SampleLevel(sampler_MainTex, i.uv, 0);
			fixed4 colored = i.col*tex;
			return fixed4(colored.rgb*(colored.a*_Brightness), colored.a);
		}
		ENDCG
	}
}
}