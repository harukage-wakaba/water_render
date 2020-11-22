Shader "Custom/PointLight"
{
    Properties
    {
        _Color("Main Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" "LightMode" = "ForwardBase"}
        LOD 100

        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {                
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD0;

                float3 rePos : TEXCOORD1;
            };

            fixed4 _Color;

            v2f vert (appdata v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                o.rePos = mul(unity_ObjectToWorld, v.vertex).xyz;

                o.normal = UnityObjectToWorldNormal(v.normal);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = _Color;
                float3 normal = normalize(i.normal);

                //--------------------------------------
                // ライトの設定(決め打ち)

                float4 Light = float4(0.0,1.0,0.0,1.0);
                float4 Attenuation = float4(0.020f, 0.020f, 0.020f, 1.0f);

                float3 dir;
                float  len;
                float  colD;
                float  colA;

                float3 viewDir = normalize(i.rePos - _WorldSpaceCameraPos.xyz); // _WorldSpaceCameraPos … ワールド座標系のカメラの位置
                viewDir.y = -viewDir.y;
                float length_y = abs( Light.y / viewDir.y);
                float3 check_pos = viewDir * length_y;
                check_pos.y = i.rePos.y;

                //点光源の方向
                dir = Light.xyz - (i.rePos + check_pos);

                //点光源の距離
                len = length(dir);

                //点光源の方向をnormalize
                dir = dir / len;

                //拡散
                colD = saturate(dot(normalize(normal), dir));

                //減衰
                // colA = saturate(1.0f / (Attenuation.x + Attenuation.y * len + Attenuation.z * len * len));
                colA = saturate(1.0f / ( pow(len,4) * 0.00020 ) );

                float c_len = min(2.0,len) * 0.5;
                colA = cos(3.14*0.5*c_len)+cos(3.14*0.5*c_len);

                float light_col = colD * colA;

                //--------------------------------------
                // 計算結果

                col += float4(light_col, light_col, light_col, light_col);

                // col = _Color;

                // col = float4((i.rePos.z / 10.0) + 0.5,0.0,0.0, 1.0);

                return col;
            }
            ENDCG
        }
    }
}
