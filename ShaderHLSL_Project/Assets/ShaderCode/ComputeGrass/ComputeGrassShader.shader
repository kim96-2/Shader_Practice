Shader "ShaderCode/ComputeGrassShader"
{
    Properties
    {

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

            struct Grass{
                float3 position;
            };

            StructuredBuffer<Grass> _GrassBuffer;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //CBUFFER_START(UnityPerMaterial)

            //CBUFFER_END

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
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                //#if SHADER_TARGET >= 45
                    Grass grass = _GrassBuffer[IN.instanceID];
                //#else

                //#endif

			    // Position
                float4x4 modelMat = create_matrix(grass.position, float3(0.0, 1.0, 0.0), float3(0.0, 1.0, 0.0));

                //OUT.positionHCS = TransformObjectToHClip(mul(modelMat,IN.positionOS).xyz);
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz * 0.8 + grass.position);

                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 color = 0;

                half3 diffuse = half3(0.2, 1, 0.2);
                
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
