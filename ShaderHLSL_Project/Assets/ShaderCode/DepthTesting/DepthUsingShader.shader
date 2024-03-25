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
    {   //뎁스 텍스쳐가 오파크 큐 이후에 그려지므로 트렌스페런트 큐로 넣어줌     
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

            //뎁스 관련 사용을 위한 인클루드
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
            struct Attributes
            {
                float4 positionOS   : POSITION;                 
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionVS : TEXCOORD0;//뷰 좌표계 변수
                float4 screenPos : TEXCOORD1;//화면 좌표계 변수

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

                OUT.screenPos =  ComputeScreenPos(OUT.positionHCS);//클립 좌표계를 화면 좌표계로 변경

                OUT.viewDir = _WorldSpaceCameraPos - positionWS;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //현데 위치의 Depth Texture 값 계산
                float rawDepth = SampleSceneDepth(IN.screenPos.xy / IN.screenPos.w);
                float sceneEyeDepth = LinearEyeDepth(rawDepth,_ZBufferParams);
                
                //현재 위치의 오브젝트 Depth 값 계산
                float fragmentEyeDepth = -IN.positionVS.z;

                float depthDis = 1 - saturate(sceneEyeDepth - fragmentEyeDepth);

                //Depth Texture를 가지고 World Position을 역변환(역 계산) 하는 방법
                float3 worldPos = _WorldSpaceCameraPos - ( (IN.viewDir / fragmentEyeDepth) * sceneEyeDepth);

                //return _BaseColor * float4(frac(worldPos), 1.0);
                return _BaseColor * depthDis;
            }
            ENDHLSL
        }
    }
}