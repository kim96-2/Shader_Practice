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
        //Depth ���� �׽����� ���� ����ũ �н� ���� ���� ����ϰ� �ƹ��͵� �׸��� �ʾƺ���
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