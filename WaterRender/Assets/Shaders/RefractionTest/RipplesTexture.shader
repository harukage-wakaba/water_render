Shader "Custom/RipplesTexture"
{
    Properties
    {
        _PrevTex("PrevTex", 2D) = "white" {}
        _PrevPrevTex("PrevPrevTex", 2D) = "white" {}
        _InputTex("InputTex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            float2 _Stride;

            sampler2D _PrevTex;
            sampler2D _PrevPrevTex;
            sampler2D _InputTex;

            float4 _InputTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _InputTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : COLOR
            {
                _Stride.x = 0.00390625 * 1.0;
                _Stride.y = 0.00390625 * 1.0;

                float2 stride = _Stride;

                half4 prev = (tex2D(_PrevTex,i.uv)*2)-1;

                half value = ( prev.r*2 - (tex2D(_PrevPrevTex,i.uv).r*2-1 ) + 

                ((tex2D(_PrevTex, half2(i.uv.x+stride.x, i.uv.y)).r * 2 - 1) + 
                 (tex2D(_PrevTex, half2(i.uv.x-stride.x, i.uv.y)).r * 2 - 1) + 
                 (tex2D(_PrevTex, half2(i.uv.x, i.uv.y+stride.y)).r * 2 - 1) +
                 (tex2D(_PrevTex, half2(i.uv.x, i.uv.y-stride.y)).r * 2 - 1) - 

                 prev.r*4) * (0.440));

                value += max((tex2D(_InputTex, i.uv).r * 2) - 1, 0);

                 value *= 0.999;

                 value = ( value+1 )*0.5;

                 value -= 0.00056;

                 float height_rate = 1.0;
                 return fixed4(value*height_rate, value*height_rate, value*height_rate, 1.0);
            }
            ENDCG
        }
    }
}
