Shader "ShaderCode/DepthTesting"
{

    Properties
    {
        //_MainTex("Main Texture",2D) = "white"{}

        //_AlphaValue("Alpha Value",Range(0,1)) = 0.5

    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        //Depth 관련 테스팅을 위해 오파크 패스 전에 뎁스 기록하고 아무것도 그리지 않아본다
        Tags {
            "RenderType" = "Opaque"
            "Queue" = "Geometry-1"
            "RenderPipeline" = "UniversalRenderPipeline"

        }

        Pass
        {
            Name "Depth Pass"
            //Tags {"LightMode" = "UniversalFoward"}
            Tags {"LightMode" = "UniversalForward"}
            //Blend Zero One
            ZWrite On
            ColorMask 0
        }

        
    }
}