Shader "Custom/WaterRipples"
{
    Properties
    {
        _MainTex("RenderTexture", 2D) = "white" {}
        _GroundTex("GroundTexture", 2D) = "white" {}
        _WallTex("WallTexture", 2D) = "white" {}
        _Color("Main Color", Color) = (1,1,1,1)
        _SpecularColor("Specular Color", Color) = (1, 1, 1)
        _Shift("Shift", Range(-1.0, 1.0)) = 0
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
                float3 tangent: TANGENT;
            };

            struct v2f
            {
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
                float4 worldPos : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 rePos : TEXCOORD2;

                float2 uv : TEXCOORD3;
                float3 tangent: TANGENT;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _GroundTex;
            sampler2D _WallTex;
            fixed4 _Color;

            float _RefractionIndex;
            float _Distance;
            float _Shiness;
            float3 _SpecularColor;
            float _Shift;



            fixed2 random2(fixed2 st) {
                st = fixed2(dot(st, fixed2(127.1, 311.7)),
                    dot(st, fixed2(269.5, 183.3)));
                return -1.0 + 2.0*frac(sin(st)*43758.5453123);
            }

            float perlinNoise(fixed2 st)
            {
                fixed2 p = floor(st);
                fixed2 f = frac(st);
                fixed2 u = f * f*(3.0 - 2.0*f);

                float v00 = random2(p + fixed2(0, 0));
                float v10 = random2(p + fixed2(1, 0));
                float v01 = random2(p + fixed2(0, 1));
                float v11 = random2(p + fixed2(1, 1));

                return lerp(lerp(dot(v00, f - fixed2(0, 0)), dot(v10, f - fixed2(1, 0)), u.x),
                    lerp(dot(v01, f - fixed2(0, 1)), dot(v11, f - fixed2(1, 1)), u.x),
                    u.y) + 0.5f;
            }

            float3 modify(float3 pos)
            {
                float rate = 0.20;
                float noise_y = perlinNoise(fixed2((pos.x + _Time.x*5.0) / rate, (pos.z + _Time.x*5.0) / rate));
                return float3(pos.x, noise_y*0.060, pos.z);
                // return float3(pos.x,( pos.y + sin(pos.x * 8.0 + _Time.x * 15.0) * cos(pos.z * 8.0 + _Time.x * 15.0))*0.020, pos.z);
            }

            float3 ripples(float3 pos,float2 texcoord_xy)
            {
                float height_rate = 0.05;

                float d = ( tex2Dlod(_MainTex, float4(texcoord_xy, 0, 0)).r ) * height_rate;
                float height_y = min(pos.y+d,0.01);
                return float3(pos.x, height_y, pos.z);
            }

            float2 getAdjUV(float3 v_pos)
            {
                // 水面の広さ
                float water_width = 10.0f; // x:-5 ~ +5
                float water_height = 10.0f; // y:-5 ~ +5
                float2 adj_uv = float2((v_pos.x + (water_width*0.5)) / water_width, (v_pos.z + (water_height*0.5)) / water_height);
                return adj_uv;
            }

            v2f vert(appdata v)
            {
                v2f o;

                // float3 pos = ripples(v.pos, v.uv);
                float3 pos = ripples(v.pos, getAdjUV(v.pos));

                float3 tangent = v.tangent;
                float3 binormal = normalize(cross(v.normal, tangent));

                float delta = 0.00390625 * 2.0;
                // float3 posT = modify(v.pos + tangent * delta);
                float3 posT = ripples(v.pos + tangent * delta, getAdjUV(v.pos) + float2(delta, 0.0));

                // float3 posB = modify(v.pos + binormal * delta);
                float3 posB = ripples(v.pos + binormal * delta, getAdjUV(v.pos) + float2(0.0, delta));

                float3 modifiedTangent = posT - pos;
                float3 modifiedBinormal = posB - pos;

                o.normal = normalize(cross(modifiedTangent, modifiedBinormal));

                o.pos = UnityObjectToClipPos(pos);

                // o.pos = UnityObjectToClipPos(v.pos); // 

                // o.worldPos = ComputeGrabScreenPos(o.pos);

                o.rePos = mul(unity_ObjectToWorld, pos).xyz;

                // o.rePos = mul(unity_ObjectToWorld, v.pos).xyz; // 
                // o.normal = UnityObjectToWorldNormal(v.normal); // 

                o.uv = TRANSFORM_TEX(v.uv,_MainTex);

                o.tangent = v.tangent;

                return o;
            }

            float schlickFresnel(float cosine) {
                float r0 = (1 - _RefractionIndex) / (1 + _RefractionIndex);
                r0 = r0 * r0;
                return r0 + (1 - r0) * pow(1 - cosine, 5);
            }

            // pos … 水面の座標
            // normal … 水面の法線
            float3 getUnderPos(float3 pos,float normal)
            {
                float refractionIndex = 1.33;
                float distance = -1.0;// -1.0 … 水底のy座標

                float3 re_right_pos = float3(pos.x, pos.y + 1.0, pos.z);
                float3 re_viewDir = normalize(pos - re_right_pos); // _WorldSpaceCameraPos … ワールド座標系のカメラの位置
                re_viewDir = refract(re_viewDir, normal, 1.0 / refractionIndex);
                float re_distance_u = abs(distance - pos.y); // -1.0 … 水底のy座標
                float re_length_y = abs(re_distance_u / re_viewDir.y); // distance_u … 水面から水底までの距離
                float3 re_u_viewDir = re_viewDir * re_length_y;
                float3 re_water_under_pos = pos + re_u_viewDir;

                return re_water_under_pos;
            }

            float3 getNoiseNormal(float3 water_pos, float3 water_tangent)
            {
                float3 flat_normal = float3(0.0, 1.0, 0.0);

                float3 pos = modify(water_pos);
                float3 tangent = water_tangent;
                float3 binormal = normalize(cross(flat_normal, tangent));

                float delta = 0.05;
                float3 posT = modify(water_pos + tangent * delta);
                float3 posB = modify(water_pos + binormal * delta);

                float3 modifiedTangent = posT - pos;
                float3 modifiedBinormal = posB - pos;

                return normalize(cross(modifiedTangent, modifiedBinormal));
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // _RefractionIndex = 1.33;
                _RefractionIndex = 1.33;

                _Distance = -1.0;// -1.0 … 水底のy座標

                float3 normal = normalize(i.normal);

                float3 viewDir = normalize(i.rePos - _WorldSpaceCameraPos.xyz); // _WorldSpaceCameraPos … ワールド座標系のカメラの位置

                viewDir = refract(viewDir, normal,1.0 / _RefractionIndex);

                float3 tmp = i.rePos / 10.0 + 0.50;
                float distance_u = abs(_Distance - i.rePos.y); // -1.0 … 水底のy座標
                float length_y = abs(distance_u / viewDir.y); // distance_u … 水面から水底までの距離
                float3 u_viewDir = viewDir * length_y;
                float3 water_under_pos = i.rePos + u_viewDir;

                float2 screenUv = float2(0.0,0.0);

                float2 border_left_up = float2(1.0,1.0);
                float2 border_right_up = float2(-1.0, 1.0);

                float2 border_left_down = float2(1.0, -1.0);
                float2 border_right_down = float2(-1.0, -1.0);

                if (water_under_pos.x <= -5.0)
                {
                    float distance_l = abs(-5.0 - i.rePos.x);
                    float length_l = abs(distance_l / viewDir.x);
                    float3 l_viewDir = viewDir * length_l;
                    float3 water_left_pos = i.rePos + l_viewDir;

                    float2 water_left_pos_v2 = float2(water_left_pos.x, water_left_pos.z);

                    if (dot(border_left_up, water_left_pos_v2) < 0.0 && dot(border_left_down, water_left_pos_v2) < 0.0)
                    {

                        water_left_pos.y = water_left_pos.y * -1.0;

                        screenUv = float2((water_left_pos.y / 10.0 + 0.40)*16.0, (water_left_pos.z / 10.0 + 0.50)*16.0);

                        fixed4 col = tex2D(_WallTex, screenUv);
                        col *= _Color;
                        return col;
                    }
                }

                if (water_under_pos.x >= 5.0)
                {
                    float distance_l = abs(5.0 - i.rePos.x);
                    float length_l = abs(distance_l / viewDir.x);
                    float3 l_viewDir = viewDir * length_l;
                    float3 water_left_pos = i.rePos + l_viewDir;

                    float2 water_left_pos_v2 = float2(water_left_pos.x, water_left_pos.z);

                    if (dot(border_right_up, water_left_pos_v2) < 0.0 && dot(border_right_down, water_left_pos_v2) < 0.0)
                    {
                        water_left_pos.y = water_left_pos.y * -1.0;

                        screenUv = float2((water_left_pos.y / 10.0 + 0.40)*16.0, 1.0 - (water_left_pos.z / 10.0 + 0.50)*16.0);

                        fixed4 col = tex2D(_WallTex, screenUv);
                        col *= _Color;
                        return col;
                    }
                }

                if (water_under_pos.z >= 5.0)
                {
                    float distance_l = abs(5.0 - i.rePos.z);
                    float length_l = abs(distance_l / viewDir.z);
                    float3 l_viewDir = viewDir * length_l;
                    float3 water_left_pos = i.rePos + l_viewDir;

                    screenUv = float2((water_left_pos.x / 10.0)*16.0,1.0 - (water_left_pos.y / 10.0 + 0.50)*16.0 + 0.40);

                    fixed4 col = tex2D(_WallTex, screenUv);
                    col *= _Color;
                    return col;
                }

                if (water_under_pos.z <= -5.0)
                {
                    float distance_l = abs(-5.0 - i.rePos.z);
                    float length_l = abs(distance_l / viewDir.z);
                    float3 l_viewDir = viewDir * length_l;
                    float3 water_left_pos = i.rePos + l_viewDir;

                    screenUv = float2(1.0 - (water_left_pos.x / 10.0)*16.0, 1.0 - (water_left_pos.y / 10.0 + 0.50)*16.0 + 0.40);

                    fixed4 col = tex2D(_WallTex, screenUv);
                    col *= _Color;
                    return col;
                }




                // float2 screenUv = (refractScreenPos.xy / refractScreenPos.w) * 0.5 + 0.5;

                // 10.0 … 床の広さ    16.0 … 床(Ground)や壁(Wall_0X)のテクスチャはTilingの設定でそれぞれ16を設定している

                float tiling_x = 16.0;
                float tiling_y = 16.0;

                screenUv = float2((water_under_pos.x / 10.0*tiling_x) + 0.50, (water_under_pos.z / 10 * tiling_y) + 0.50);

                i.uv.x = i.uv.x;
                i.uv.y = i.uv.y;

                fixed4 col = tex2D(_GroundTex, screenUv);
                col *= _Color;

                //----------------------------------------------------
                // コースティクス

                float micro = 0.0010;
                float micro_rate = 1.0;

                // 変形前の水面
                float3 flat_pos = float3(i.rePos.x,0.0,i.rePos.z);
                float3 flat_normal = float3(0.0, 1.0, 0.0);
                float3 flat_under_pos = getUnderPos(flat_pos, flat_normal);

                // 変形前の横隣の水面
                float3 flat_ddx_pos = flat_pos + ddx(flat_pos) * micro_rate;
                // float3 flat_ddx_pos = float3(flat_pos.x+ micro, flat_pos.y, flat_pos.z);
                float3 flat_ddx_under_pos = getUnderPos(flat_ddx_pos, flat_normal);

                // 変形前の縦隣の水面
                float3 flat_ddy_pos = flat_pos + ddy(flat_pos) * micro_rate;
                // float3 flat_ddy_pos = float3(flat_pos.x, flat_pos.y, flat_pos.z + micro);
                float3 flat_ddy_under_pos = getUnderPos(flat_ddy_pos, flat_normal);

                // 変形前の隣接ピクセルとの面積
                float flat_area = length(flat_ddx_under_pos - flat_under_pos) * length(flat_ddy_under_pos - flat_under_pos);

                ///

                // 変形後の水面
                float3 wave_pos = float3(i.rePos.x, i.rePos.y, i.rePos.z);
                float3 wave_normal = normalize(i.normal);
                float3 wave_under_pos = getUnderPos(wave_pos, wave_normal);

                // 変形後の横隣の水面
                float3 wave_ddx_pos = wave_pos + ddx(wave_pos) * micro_rate;
                // float3 wave_ddx_pos = float3(wave_pos.x + micro, wave_pos.y, wave_pos.z);
                float3 wave_ddx_normal = getNoiseNormal(wave_ddx_pos, i.tangent);
                float3 wave_ddx_under_pos = getUnderPos(wave_ddx_pos, wave_ddx_normal);

                // 変形後の縦隣の水面
                float3 wave_ddy_pos = wave_pos + ddy(wave_pos) * micro_rate;
                // float3 wave_ddy_pos = float3(wave_pos.x, wave_pos.y, wave_pos.z + micro);
                float3 wave_ddy_normal = getNoiseNormal(wave_ddy_pos,i.tangent);
                float3 wave_ddy_under_pos = getUnderPos(wave_ddy_pos, wave_ddy_normal);

                // 変形後の隣接ピクセルとの面積
                float wave_area = length(wave_ddx_under_pos - wave_under_pos) * length(wave_ddy_under_pos - wave_under_pos);

                // 面積の差
                float caustics_rate = max(flat_area / wave_area, 0.010);

                caustics_rate *= 0.260;

                caustics_rate = caustics_rate + 1.20;

                // caustics_rate = caustics_rate * 0.80;

                /*

                _Distance = -0.010;

                float3 flatPos = i.rePos;
                flatPos.y = 0.0; // 平面の時の水の高さは0.0
                float3 flat_normal = float3(0.0,1.0,0.0);
                float3 right_pos = float3(flatPos.x, flatPos.y+1.0, flatPos.z);
                float3 flat_viewDir = normalize(flatPos - right_pos); // _WorldSpaceCameraPos … ワールド座標系のカメラの位置
                flat_viewDir = refract(flat_viewDir, flat_normal, 1.0 / _RefractionIndex);
                float flat_distance_u = abs(_Distance - flatPos.y); // -1.0 … 水底のy座標
                float flat_length_y = abs(flat_distance_u / flat_viewDir.y); // distance_u … 水面から水底までの距離
                float3 flat_u_viewDir = flat_viewDir * flat_length_y;
                float3 flat_water_under_pos = flatPos + flat_u_viewDir;

                // i.rePos = flatPos;
                // normal = flat_normal;
                float3 re_right_pos = float3(i.rePos.x, i.rePos.y + 1.0, i.rePos.z);
                float3 re_viewDir = normalize(i.rePos - re_right_pos); // _WorldSpaceCameraPos … ワールド座標系のカメラの位置
                re_viewDir = refract(re_viewDir, normal, 1.0 / _RefractionIndex);
                float re_distance_u = abs(_Distance - i.rePos.y); // -1.0 … 水底のy座標
                float re_length_y = abs(re_distance_u / re_viewDir.y); // distance_u … 水面から水底までの距離
                float3 re_u_viewDir = re_viewDir * re_length_y;
                float3 re_water_under_pos = i.rePos + re_u_viewDir;


                // 10.0 … 床の広さ    16.0 … 床(Ground)や壁(Wall_0X)のテクスチャはTilingの設定でそれぞれ16を設定している
                float2 re_screenUv = float2((re_water_under_pos.x / 10.0*1.0) + 0.50, (re_water_under_pos.z / 10 * 1.0) + 0.50);
                float2 flat_screenUv = float2((flat_water_under_pos.x / 10.0*1.0) + 0.50, (flat_water_under_pos.z / 10 * 1.0) + 0.50);

                float length_rate = 1.0;

                float beforeArea = length(ddx(flat_water_under_pos))*length_rate * length(ddy(flat_water_under_pos))*length_rate;
                float afterArea = length(ddx(re_water_under_pos))*length_rate * length(ddy(re_water_under_pos))*length_rate;

                float caustics_rate = max(beforeArea / afterArea,0.90);

                caustics_rate *= 0.20;

                */

                // col = tex2D(_MainTex, i.uv);
                // return col;
                // col = tex2Dproj(_GrabTexture, i.worldPos - refractDir4*0.25);
                // col = float4(tmp, 1.0);
                // col = float4(caustics_rate*0.2, 0.0, 0.0, 1.0);

                // col = float4(caustics_rate, 0.0,0.0,1.0f);

                // caustics_rate = 0.960 + i.rePos.y*2.80;

                // caustics_rate = 0.250 + ( normal.y * ( 2.0 - length_y ) );

                // col *= float4(caustics_rate, caustics_rate, caustics_rate, 1.0f);

                float c = (flat_area * wave_area * 1000000.0) * 0.20 + 0.80;

                // c = max(c,0.48);

                c = caustics_rate * 1.0;

                // if (normal.y < 0.99990)

                // col = float4(c,c,c,1.0f);

                // col *= float4(c,c,c,1.0f);

                return col;
            }

            ENDCG
        }
    }
}
