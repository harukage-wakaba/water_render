Shader "Custom/Water"
{
    Properties
    {
        _MainTex ("RenderTexture", 2D) = "white" {}
        _Color("Main Color", Color) = (1,1,1,1)
        _SpecularColor("Specular Color", Color) = (1, 1, 1)
        _Shift("Shift", Range(-100.0, 100.0)) = 0
    }
    SubShader
    {
        Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" "LightMode" = "ForwardBase"}
        LOD 100

        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        GrabPass
        {
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            // #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            sampler2D _GrabTexture;

            struct appdata
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
                float4 worldPos : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 rePos : TEXCOORD2;

                float2 uv : TEXCOORD3;
            };

            sampler2D _MainTex;
            fixed4 _Color;
            float4 _MainTex_ST;

            float _RefractionIndex;
            float _Distance;
            float _Shiness;
            float3 _SpecularColor;
            float _Shift;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.pos);

                o.worldPos = ComputeGrabScreenPos(o.pos);

                o.rePos = mul(unity_ObjectToWorld, v.pos).xyz;

                o.normal = UnityObjectToWorldNormal(v.normal);

                o.uv = TRANSFORM_TEX(v.uv,_MainTex);

                return o;
            }

            float schlickFresnel(float cosine) {
                float r0 = (1 - _RefractionIndex) / (1 + _RefractionIndex);
                r0 = r0 * r0;
                return r0 + (1 - r0) * pow(1 - cosine, 5);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                _RefractionIndex = 1.33;
                _Distance = 1.0;

                float3 normal = normalize(i.normal);

                float3 viewDir = normalize(i.rePos - _WorldSpaceCameraPos.xyz); // _WorldSpaceCameraPos … ワールド座標系のカメラの位置

                viewDir = float3(0.0, -1.0, 0.0);

                float length_y = 1.0 / viewDir.y; // 1.0 … 水面から水底までの距離
                viewDir = viewDir * length_y;
                float3 water_under_pos = i.rePos + viewDir;

                float3 water_cam_pos = float3(water_under_pos.x, 8.50, water_under_pos.z);
                float3 re_viewDir = normalize( water_cam_pos - water_under_pos);
                float re_length_y = 1.0 / re_viewDir.y;
                re_viewDir = re_viewDir * re_length_y;
                float3 water_on_pos = water_under_pos + re_viewDir;

                float2 screenUv = float2(water_on_pos.x/10+0.50, water_on_pos.z/10.0+0.50);
                // screenUv.y = 1.0 - screenUv.y;

                /*
                float3 refractDir = refract(viewDir, normal, 1.0 / _RefractionIndex);
                float3 refractPos = i.worldPos + refractDir * _Shift;
                float4 refractScreenPos = mul(UNITY_MATRIX_VP, float4(refractPos, 1.0));
                float4 refractDir4 = float4(refractDir,0.0);
                float2 screenUv = (refractScreenPos.xy / refractScreenPos.w) * 0.5 + 0.5
                float3 refractCol = tex2D(_GrabTexture, screenUv).xyz;
                fixed4 col = float4(refractCol,1.0);
                col = tex2D(_GrabTexture, i.worldPos);
                */

                i.uv.x = i.uv.x;
                i.uv.y = i.uv.y;

                fixed4 col = tex2D(_MainTex, screenUv);
                // col = tex2D(_MainTex, i.uv);

                // return col;

                // col = tex2Dproj(_GrabTexture, i.worldPos - refractDir4*0.25);

                col *= _Color;

                return col;

                ///

                // sample the texture
                // fixed4 col = tex2D(_GrabTexture, i.worldPos);
                // apply fog
                // UNITY_APPLY_FOG(i.fogCoord, col);
                // col = _Color;
                // return col;

                ///
            }
            ENDCG
        }
    }
}
