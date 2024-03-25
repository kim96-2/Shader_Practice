Shader "ShaderCode/ShaderUsing"
{    
    // The _BaseColor variable is visible in the Material's Inspector, as a field 
    // called Base Color. You can use it to select a custom color. This variable
    // has the default value (1, 1, 1, 1).
    Properties
    { 
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
    }
    
    SubShader
    {   //���� �ؽ��İ� ����ũ ť ���Ŀ� �׷����Ƿ� Ʈ�����䷱Ʈ ť�� �־���     
        Tags 
        {
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"         
        }
                
        Pass
        {            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //���� ���� ����� ���� ��Ŭ���
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
            struct Attributes
            {
                float4 positionOS   : POSITION;                 
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionVS : TEXCOORD0;//�� ��ǥ�� ����
                float4 screenPos : TEXCOORD1;//ȭ�� ��ǥ�� ����

                float3 viewDir : TEXCOORD2;
            };

            // To make the Unity shader SRP Batcher compatible, declare all
            // properties related to a Material in a a single CBUFFER block with 
            // the name UnityPerMaterial.
            CBUFFER_START(UnityPerMaterial)
                // The following line declares the _BaseColor variable, so that you
                // can use it in the fragment shader.
                half4 _BaseColor;            
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);

                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.positionVS = TransformWorldToView(positionWS);

                OUT.screenPos =  ComputeScreenPos(OUT.positionHCS);//Ŭ�� ��ǥ�踦 ȭ�� ��ǥ��� ����

                OUT.viewDir = _WorldSpaceCameraPos - positionWS;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //���� ��ġ�� Depth Texture �� ���
                float rawDepth = SampleSceneDepth(IN.screenPos.xy / IN.screenPos.w);
                float sceneEyeDepth = LinearEyeDepth(rawDepth,_ZBufferParams);
                
                //���� ��ġ�� ������Ʈ Depth �� ���
                float fragmentEyeDepth = -IN.positionVS.z;

                float depthDis = 1 - saturate(sceneEyeDepth - fragmentEyeDepth);

                //Depth Texture�� ������ World Position�� ����ȯ(�� ���) �ϴ� ���
                float3 worldPos = _WorldSpaceCameraPos - ( (IN.viewDir / fragmentEyeDepth) * sceneEyeDepth);

                //return _BaseColor * float4(frac(worldPos), 1.0);
                return _BaseColor * depthDis;
            }
            ENDHLSL
        }
    }
}