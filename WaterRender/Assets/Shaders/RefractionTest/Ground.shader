Shader "Custom/Ground"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("Main Color", Color) = (1,1,1,1)
        _CamMtx1("Cam Mtx1", Vector) = (0,0,0,0)
        _CamMtx2("Cam Mtx2", Vector) = (0,0,0,0)
        _CamMtx3("Cam Mtx3", Vector) = (0,0,0,0)
        _CamMtx4("Cam Mtx4", Vector) = (0,0,0,0)
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

            sampler2D _MainTex;
            fixed4 _Color;
            float4 _CamMtx1;
            float4 _CamMtx2;
            float4 _CamMtx3;
            float4 _CamMtx4;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                 float4x4 CamMtx = UNITY_MATRIX_VP;

                 _CamMtx1 = CamMtx[0];
                 _CamMtx2 = CamMtx[1];
                 _CamMtx3 = CamMtx[2];
                 _CamMtx4 = CamMtx[3];

                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

                return col;
            }
            ENDCG
        }
    }
}
