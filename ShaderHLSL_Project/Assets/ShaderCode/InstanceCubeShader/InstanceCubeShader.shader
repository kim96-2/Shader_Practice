Shader "ShaderCode/InstanceCubeShader"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalRenderPipeline" 
        }

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5

            //#pragma instancing_options procedural:ConfigureProcedural

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            struct Cube
            {
                float3 position;
                float4 color;
            };

            #if SHADER_TARGET >= 45
                StructuredBuffer<Cube> cubes;
            #endif

            float4x4 _ModelMatrix;

            struct Attributes
            {
                float4 positionOS   : POSITION;

                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;//노멀맵 계산용 Tangent
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float3 color        : TEXCOORD2;

            };

            Varyings vert (Attributes IN, uint instanceID : SV_InstanceID)
            {
                #if SHADER_TARGET >= 45
                    Cube data = cubes[instanceID];
                #else
                    Cube data = 0;
                #endif

                float3 localPosition = IN.positionOS.xyz;
                float3 worldPosition = data.position.xyz + localPosition;
                worldPosition = mul(_ModelMatrix, float4(worldPosition, 1)).xyz;

                float3 worldNormal = TransformObjectToWorldNormal(IN.normalOS);

                float3 color = data.color.rgb;

                Varyings OUT;
                OUT.positionCS = TransformWorldToHClip(worldPosition);
                OUT.positionWS = worldPosition;

                OUT.normalWS = worldNormal;

                OUT.color = color;

                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                //Light mainLight = GetMainLight();

                //float NdotL = dot(mainLight.direction, IN.normalWS);

                //return half4(IN.color * saturate(NdotL * 0.5 + 0.5), 1);

                InputData inputData = (InputData)0;
                inputData.positionWS = IN.positionWS;
                inputData.normalWS = IN.normalWS;
                inputData.viewDirectionWS = normalize(_WorldSpaceCameraPos - IN.positionWS);
                inputData.bakedGI = SampleSH(IN.normalWS);

                half4 color = UniversalFragmentBlinnPhong(inputData, IN.color, 1, 1, 0, 1, float3(0, 1, 0));

                return color;
            }

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM

             #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5

            //#pragma instancing_options procedural:ConfigureProcedural

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            struct Cube
            {
                float3 position;
                float4 color;
            };

            #if SHADER_TARGET >= 45
                StructuredBuffer<Cube> cubes;
            #endif

            float4x4 _ModelMatrix;

            struct Attributes
            {
                float4 positionOS   : POSITION;

                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;//노멀맵 계산용 Tangent
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;

            };

            Varyings vert (Attributes IN, uint instanceID : SV_InstanceID)
            {
                #if SHADER_TARGET >= 45
                    Cube data = cubes[instanceID];
                #else
                    Cube data = 0;
                #endif

                float3 localPosition = IN.positionOS.xyz;
                float3 worldPosition = data.position.xyz + localPosition;
                worldPosition = mul(_ModelMatrix, float4(worldPosition, 1)).xyz;

                Varyings OUT;
                OUT.positionCS = TransformWorldToHClip(worldPosition);

                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                return 0;
            }

            ENDHLSL
        }
    }
}
