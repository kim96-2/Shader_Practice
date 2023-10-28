Shader "ShaderCode/Stencil"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    {
        
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {

        Tags {
        "RenderType" = "Opaque" 
        "Queue" = "Geometry+1"
        "RenderPipeline" = "UniversalRenderPipeline" 
        }

        Pass
        {
            Zwrite Off
            //Blend Zero One

            //Cull Off
            ColorMask 0


            /*
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            


            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 positionOS   : POSITION;                 
            };

            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionHCS  : SV_POSITION;
            };            

            Varyings vert(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                // Returning the output.
                return OUT;
            }

       
            half4 frag() : SV_Target
            {
                half4 customColor;
                customColor = half4(0.5, 0, 0, 1);
                return customColor;
            }
            ENDHLSL
            */
        }
    }
}