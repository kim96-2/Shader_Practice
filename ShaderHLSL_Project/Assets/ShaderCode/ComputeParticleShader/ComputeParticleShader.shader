Shader "ShaderCode/ComputeParticle"
{
    Properties
    {
        _PointSize("Point size", Float) = 5.0
    }

    SubShader
    {
        
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            //#pragma target 4.5

            struct Particle{
                float3 position;
                float3 velocity;
                float headAmount;
                float colorAmount;
            };

            StructuredBuffer<Particle> _ParticleBuffer;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)

            float _PointSize;

            CBUFFER_END

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

                return mul(TR_Mat, float4x4(
                        _PointSize, 0, 0, 0,
                        0, _PointSize, 0, 0,
                        0, 0, _PointSize, 0,
                        0, 0, 0, 1
                    ));
            }

            float3 Unity_ColorspaceConversion_RGB_RGB_float(float3 In)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 P = abs(frac(In.xxx + K.xyz) * 6.0 - K.www);
                return In.z * lerp(K.xxx, saturate(P - K.xxx), In.y);
            }

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                uint instanceID : SV_InstanceID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS     : TEXCOORD0;
                float color         : COLOR;
                float4 uv            : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                //#if SHADER_TARGET >= 45
                    Particle particle = _ParticleBuffer[IN.instanceID];
                //#else
                    //Particle particle = (Particle)0;
                //#endif

			    // Position
                float4x4 modelMat = create_matrix(particle.position, normalize(particle.velocity), float3(0.0, 1.0, 0.0));

                OUT.positionHCS = TransformObjectToHClip(mul(modelMat,IN.positionOS));

                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

                OUT.color = particle.colorAmount;//particle.headAmount;

                OUT.uv = ComputeScreenPos(OUT.positionHCS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 color = 0;

                half3 diffuse = Unity_ColorspaceConversion_RGB_RGB_float(float3(IN.color, 0.9, 1.0));
                
                Light light= GetMainLight();

                float ndotl = dot(normalize(IN.normalWS), light.direction);

                half3 ambient = SampleSH(IN.normalWS) * diffuse;

                color = saturate(ndotl) * diffuse + ambient;

                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}