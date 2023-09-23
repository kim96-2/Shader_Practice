// This shader fills the mesh shape with a color predefined in the code.
Shader "ShaderCode/UnlitShader"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    { 
        _Color1("Base Color",Color) = (1,1,1,1)
        _Color2("Base Color",Color) = (1,1,1,1)
        _MainTex("MainTex",2D) = "White"

        _Metallic("Metallic",float) = 0
        _Value("Value",float) = 0
    }

    // The SubShader block containing the Shader code.
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            // This line defines the name of the vertex shader.
            #pragma vertex vert
            // This line defines the name of the fragment shader.
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
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 positionOS   : POSITION;
                float2 uv : TEXCOORD0;
                half3 normal : NORMAL;
            };

            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionHCS  : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 normal : TEXCOORD1;
                half3 viewDir : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color1,_Color2;
                float4 _MainTex_ST;

                float _Metallic;
                float _Value;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Varyings OUT;
                // The TransformObjectToHClip function transforms vertex positions
                // from object space to homogenous clip space.
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);

                OUT.normal = TransformObjectToWorldNormal(IN.normal);

                OUT.viewDir = normalize(_WorldSpaceCameraPos - TransformObjectToWorld(IN.positionOS.xyz));

                // Returning the output.
                return OUT;
            }

            // The fragment shader definition.
            half4 frag(Varyings IN) : SV_Target
            {

                float NoV = saturate(dot(IN.viewDir,IN.normal));
                float frensal = _Metallic + (1 - _Metallic) * pow(1 - NoV, 5);

                half4 customColor;
                half4 frensalColor;
                //Defining the color variable and returning it.
                //customColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,IN.uv);
                frensalColor = lerp(_Color1,_Color2,GetNormalizedScreenSpaceUV(IN.positionHCS).y * 1.3);
                customColor = (frensal < _Value)? SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,IN.uv) : frensalColor;

                return customColor;
            }
            ENDHLSL
        }
    }
}