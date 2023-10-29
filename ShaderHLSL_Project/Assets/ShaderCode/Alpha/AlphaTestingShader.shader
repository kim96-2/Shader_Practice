Shader "ShaderCode/AlphaTest"
{

    Properties
    {
        _MainTex("Main Texture",2D) = "white"{}

        _AlphaValue("Alpha Value",Range(0,1)) = 0.5

    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags {//알파 적용을 위해 Transparent 큐로 돌리는중
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"

        }

        Pass
        {
            Name "Depth Pass"
            //Tags {"LightMode" = "SRPDefaultUnlit"}
            ZWrite On
            ColorMask 0
        }

        Pass
        {
            Name "Alpha Pass"
            Tags {"LightMode" = "UniversalForward"}
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            
            /*
            Tags{"LightMode" = "UniversalFoward"}
            ZWrite Off       
            Blend SrcColor OneMinusSrcAlpha
            */

            //ColorMask rgb (ColorMask 0말고 다른거 어떻게 쓰는지 확인해야 할듯)

            HLSLPROGRAM

            #pragma vertex vert 
            #pragma fragment frag

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            

            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
            };            

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _AlphaValue;
            CBUFFER_END

            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings vert(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Varyings OUT;
                
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

                // Returning the output.
                return OUT;
            }

            // The fragment shader definition.            
            half4 frag(Varyings IN) : SV_Target
            {
                half4 col;

                col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,IN.uv);

                col = half4(col.rgb,_AlphaValue);

                return col;
            }
            ENDHLSL
        }

        
    }
}