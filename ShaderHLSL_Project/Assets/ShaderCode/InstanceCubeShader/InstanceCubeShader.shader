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
                float3 normalWS     : TEXCOORD0;
                float3 color        : TEXCOORD1;

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
                float3 worldNormal = TransformObjectToWorldNormal(IN.normalOS);

                float3 color = data.color.rgb;

                Varyings OUT;
                OUT.positionCS = TransformWorldToHClip(worldPosition);
                //OUT.pos = mul(UNITY_MATRIX_VP, float4(worldPosition, 1.0f));

                OUT.color = color;

                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {

                return half4(IN.color, 1);
            }

            ENDHLSL
        }
    }
}
