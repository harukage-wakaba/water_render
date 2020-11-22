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
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float3 tangent: TANGENT;
            };

            struct v2f
            {                
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD0;
                float3 rePos : TEXCOORD1;
            };

            fixed4 _Color;

            float3 modify(float3 pos)
            {
                return float3(pos.x, (pos.y + sin(pos.x * 8.0 + _Time.x * 300.0) * cos(pos.z * 8.0 + _Time.x * 30.0))*0.10, pos.z);
            }

            v2f vert (appdata v)
            {
                v2f o;


                float3 pos = modify(v.vertex);
                float3 tangent = v.tangent;
                float3 binormal = normalize(cross(v.normal, tangent));

                float delta = 0.05;
                float3 posT = modify(v.vertex + tangent * delta);
                float3 posB = modify(v.vertex + binormal * delta);

                float3 modifiedTangent = posT - pos;
                float3 modifiedBinormal = posB - pos;

                o.normal = normalize(cross(modifiedTangent, modifiedBinormal));
                o.pos = UnityObjectToClipPos(pos);

                // o.pos = UnityObjectToClipPos(v.vertex);
                // o.normal = UnityObjectToWorldNormal(v.normal);

                o.rePos = mul(unity_ObjectToWorld, v.vertex).xyz;

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

                viewDir = refract(viewDir, normal, 1.0 / 1.0);

                viewDir.y = -viewDir.y;

                float length_y = abs( Light.y / viewDir.y);
                // float length_y = Light.y;
                float3 check_pos = viewDir * length_y;

                // check_pos.y = i.rePos.y;

                //点光源の方向
                dir = Light.xyz - (i.rePos + check_pos);

                //点光源の距離
                len = length(dir);

                //点光源の方向をnormalize
                dir = dir / len;

                //拡散
                colD = saturate(dot(normalize(normal), normalize(Light.xyz - i.rePos)));

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
