Shader "ParticleCloud/Pass"
{
Properties
{
	[NoScaleOffset]
	_Buffer ("Positions", 2D) = "gray" {}
	_Str    ("Strength", Range(-5.0, 5.0)) = 1.0
}
SubShader
{
    Tags { "Queue"="Overlay+1000" "IgnoreProjector"="True" "RenderType"="Overlay" "PreviewType"="Plane" "DisableBatching"="True"}
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

		Texture2D<float4> _Buffer;
		uniform float _Str;
		
		//--- Vertex shader ---//
		float4 vert(float4 vertex : POSITION) : SV_Position
		{
			// TODO place vertices at camera near clip
			return UnityObjectToClipPos(vertex);
		}

		//--- Fragment shader ---//
		float4 frag (float4 i : SV_Position) : SV_Target
		{
			if ((i.x+i.y) <= 1.1) // Store camera
				return EncodeColor(float4(_WorldSpaceCameraPos, _Str));
			return _Buffer.Load(i.xyz); // Pass-through
		}
		ENDCG
	}
}
}