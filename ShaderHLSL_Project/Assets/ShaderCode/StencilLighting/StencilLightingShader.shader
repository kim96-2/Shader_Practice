Shader "CustomShader/StencilLighting"
{
    Properties
    {
        [HDR]_LightColor ("Light Color", color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" }
        
        HLSLINCLUDE//HLSLPROGRAM 이 아닌 HLSLINCLUDE로 정의

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            half4 _LightColor;
        CBUFFER_END
        
        struct Attributes
        {
            float4 positionOS   : POSITION;       
            float2 uv           : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionHCS  : SV_POSITION;
            float2 uv           : TEXCOORD0;
        };            


        Varyings vert(Attributes IN)
        {

            Varyings OUT;

            OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
            OUT.uv = IN.uv;

            return OUT;
        }

        ENDHLSL

        Pass
        {
            //라이트 범위 마스킹 1
            Name "Stencil Mask 1"
            Tags
            {
                "LightMode" = "StencilMask_1"
            }

            Stencil
            {
                Ref 1
                Comp Greater
                Pass Replace
            }

            Ztest Greater
            ZWrite Off

            Cull front

            ColorMask 0

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            half4 frag(Varyings IN) : SV_Target
            {
                return _LightColor;
            }

            ENDHLSL

        }

        Pass
        {
            //라이트 범위 마스킹 2(테스트를 위해 만들었지만 테스트 실패로 사용 안함)
            Name "Stencil Mask 2"
            Tags
            {
                "LightMode" = "StencilMask_2"
            }

            Stencil
            {
                Ref 1
                Comp Less

                Pass IncrSat
            }

            Ztest Less
            ZWrite Off

            Cull back

            ColorMask 0

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            half4 frag(Varyings IN) : SV_Target
            {
                return _LightColor;
            }

            ENDHLSL

        }

        Pass
        {
            //라이트 외부를 그려주는 함수
            Name "Stencil Outside"
            Tags
            {
                "LightMode" = "StencilOutside"
            }

            Stencil
            {
                Ref 1
                Comp Equal

                Pass Zero
                Fail Zero
                ZFail Zero
            }

            ZWrite Off

            Blend DstColor One

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            half4 frag(Varyings IN) : SV_Target
            {
                return _LightColor;
            }

            ENDHLSL

        }
    }
}
