Shader "ShaderCode/ComputeGrassShader"
{
    Properties
    {
        _Color("Main Clor", Color) = (1,1,1,1)
        _OldColor("Old Grass Color", Color) = (0,0,0,1)
        _AOColor("AO Color", Color) = (0,0,0,1)
        _AOAmount("AO Amount", Range(0, 1)) = 0.1

        [Header(Random Hight)]
        _MinHight("Min Hight", Float) = 0.8
        _MaxHight("Max Hight", Float) = 1.2
    }
    SubShader
    {
        
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Cull Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            //#pragma target 4.5

            struct Grass{
                float3 position;
                float3 windDirection;
            };

            StructuredBuffer<Grass> _GrassBuffer;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //CBUFFER_START(UnityPerMaterial)
            half4 _Color;
            half4 _OldColor;

            half4 _AOColor;
            float _AOAmount;

            float _MinHight;
            float _MaxHight;
            //CBUFFER_END

            uint rng_state;

            //Hash invented by Thomas Wang
            void wang_hash(uint seed) {
                rng_state = (seed ^ 61) ^ (seed >> 16);
                rng_state *= 9;
                rng_state = rng_state ^ (rng_state >> 4);
                rng_state *= 0x27d4eb2d;
                rng_state = rng_state ^ (rng_state >> 15);
            }

            //Xorshift algorithm from George Marsaglia's paper
            uint rand_xorshift() {
                rng_state ^= (rng_state << 13);
                rng_state ^= (rng_state >> 17);
                rng_state ^= (rng_state << 5);

                return rng_state;
            }

            float randValue() {
                return rand_xorshift() * (1.0 / 4294967296.0);
            }

            void initRand(uint seed) {
                wang_hash(seed);
            }

            float randValue(uint seed) {
                initRand(seed);
                return randValue();
            }

            float2 unity_gradientNoise_dir(float2 p)
            {
                p = p % 289;
                float x = (34 * p.x + 1) * p.x % 289 + p.y;
                x = (34 * x + 1) * x % 289;
                x = frac(x / 41) * 2 - 1;
                return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
            }

            float unity_gradientNoise(float2 p)
            {
                float2 ip = floor(p);
                float2 fp = frac(p);
                float d00 = dot(unity_gradientNoise_dir(ip), fp);
                float d01 = dot(unity_gradientNoise_dir(ip + float2(0, 1)), fp - float2(0, 1));
                float d10 = dot(unity_gradientNoise_dir(ip + float2(1, 0)), fp - float2(1, 0));
                float d11 = dot(unity_gradientNoise_dir(ip + float2(1, 1)), fp - float2(1, 1));
                fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
                return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x);
            }

            float Unity_GradientNoise_float(float2 UV, float Scale)
            {
                return unity_gradientNoise(UV * Scale) + 0.5;
            }

            float4x4 create_matrix(float3 pos, float3 dir, float3 up) {
                float3 zaxis = normalize(dir);
                float3 xaxis = normalize(cross(up, zaxis));
                float3 yaxis = cross(zaxis, xaxis);
                float4x4 TR_Mat = float4x4(
                        xaxis.x, yaxis.x, zaxis.x, pos.x,
                        xaxis.y, yaxis.y, zaxis.y, pos.y,
                        xaxis.z, yaxis.z, zaxis.z, pos.z,
                        0, 0, 0, 1
                    );

                return TR_Mat;
            }

            float3x3 rotate_matrix(float3 axis, float angle)
            {
                axis = normalize(axis);

                float c = cos(angle);
                float s = sin(angle);

                float a_x = axis.x;
                float a_y = axis.y;
                float a_z = axis.z;

                return float3x3(
                    a_x * a_x * (1 - c) + c, a_x * a_y * (1 - c) - a_z * s, a_x * a_z * (1 - c) + a_y * s,
                    a_x * a_y * (1 - c) + a_x * s, a_y * a_y * (1 - c) + c, a_y * a_z * (1 - c) + a_z * s,
                    a_x * a_z * (1 - c) + a_y * s, a_y * a_z * (1 - c) + a_x * s, a_z * a_z * (1 - c) + c
                );
            }

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv           : TEXCOORD0;
                uint instanceID : SV_InstanceID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS     : TEXCOORD0;

                float2 uv           : TEXCOORD1;
                float hash          : TEXCOORD2;
                float wind          : TEXCOORD3;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                //#if SHADER_TARGET >= 45
                    Grass grass = _GrassBuffer[IN.instanceID];
                //#else

                //#endif

                float idHash = randValue(abs(grass.position.x * 10000 + grass.position.y * 100 + 2));
                idHash = randValue(idHash * 100000);
                OUT.hash = idHash;

                //rotation to camera
                float3 pivotPosWS = TransformObjectToWorld(grass.position);
                float3 cameraLookDir = pivotPosWS - _WorldSpaceCameraPos.xyz;
                cameraLookDir.y = 0;
                cameraLookDir = normalize(cameraLookDir);

                float3 windDirection = normalize(grass.windDirection);
                float windValue = length(grass.windDirection);
                OUT.wind = windValue;

                float3 windAxis = cross(windDirection, float3(0, 1, 0));

                float3x3 windRotMat = rotate_matrix(windAxis, windValue * 3.14 * 0.25);
        
			    // Position
                float4x4 modelMat = create_matrix(0.0, cameraLookDir, float3(0.0, 1.0, 0.0));

                IN.positionOS.y *= lerp(_MinHight, _MaxHight, idHash);
                IN.positionOS = mul(modelMat, IN.positionOS);

                float3 pivotY = mul(windRotMat, float3(0, IN.positionOS.y, 0));
                IN.positionOS.xyz = float3(IN.positionOS.x, 0, IN.positionOS.z) + pivotY;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz + grass.position);
                //OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz * 0.8 + grass.position);

                OUT.normalWS = mul(windRotMat, TransformObjectToWorldNormal(IN.normalOS));
                //OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

                OUT.uv = IN.uv;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 color = 0;

                half3 diffuse = lerp(_Color.rgb, _OldColor.rgb, IN.hash);
                diffuse = lerp(_AOColor.rgb, diffuse , smoothstep(0, 1, IN.uv.y / _AOAmount));
                
                Light light = GetMainLight();

                float ndotl = dot(normalize(IN.normalWS), light.direction);

                half3 ambient = SampleSH(IN.normalWS) * diffuse;

                color = saturate(ndotl) * diffuse + ambient;

                return half4(color, 1);
                //return IN.wind;
            }
            ENDHLSL
        }
    }
}
