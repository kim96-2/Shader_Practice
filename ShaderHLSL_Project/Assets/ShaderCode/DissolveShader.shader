Shader "ShaderCode/Dissolve"
{
    Properties
    { 
        [MainTexture] _MainTex("Main Texture", 2D) = "white"{}
        _NoiseTex("Noise Texture",2D) = "White"{}
        
        _CutoffHeight("Cufoff Height",Range(-1,1)) = 0.5
        _NoisePower("Noise Power",Range(0,1)) = 0.5

        [MainColor][HDR] _MainColor("Main Color",Color) = (1,1,1,0)
        _GlowSize("Glow Size",Range(0,1)) = 0.1

    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        
        Tags { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalRenderPipeline" 
            }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            Cull off

            HLSLPROGRAM 
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            

            
            struct Attributes
            {
                
                float4 positionOS   : POSITION;      
                float2 uv : TEXCOORD0;           
            };

            struct Varyings
            {
            
                float4 positionHCS  : SV_POSITION;
                float4 positionOS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float2 noiseUV : TEXCOORD2;

            };            

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            CBUFFER_START(Unity_PerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                half _CutoffHeight,_GlowSize,_NoisePower;
                half4 _MainColor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                
                OUT.positionOS = IN.positionOS;

                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);

                OUT.noiseUV = TRANSFORM_TEX(IN.uv,_NoiseTex);

                return OUT;
            }

            // The fragment shader definition.            
            half4 frag(Varyings IN) : SV_Target
            {
                // Defining the color variable and returning it.
                half4 customColor;
                customColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex ,IN.uv);

                float noiseCutoff_1;
                float noiseCutoff_2 = (SAMPLE_TEXTURE2D(_NoiseTex,sampler_NoiseTex ,IN.noiseUV)).x;

                //noiseCutoff_2를 (0,1)에서 (-noisePower,noisePower)로 remap시킴
                noiseCutoff_2 = -_NoisePower + (noiseCutoff_2)*(_NoisePower * 2); 
                noiseCutoff_2 +=_CutoffHeight;

                //noise 외곽 공간 계산
                noiseCutoff_1 = step(IN.positionOS.y,noiseCutoff_2 + _GlowSize);
                noiseCutoff_2 = step(IN.positionOS.y,noiseCutoff_2);

                customColor = customColor * noiseCutoff_1;

                customColor = (noiseCutoff_1 - noiseCutoff_2) > 0 ? _MainColor : customColor;

                return customColor;
            }
            ENDHLSL
        }

        Pass//또는 이렇게 새로운 패스를 만들고 이미 만들어진 hlsl 셰이더를 가져올 수 있다
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Blend SrcAlpha OneMinusSrcAlpha//블렌드 스타일 적용해보기(다만 현재 Pass에서 alpha값을 변경하는게 아니라 변화 없음)
            Cull Front

            HLSLPROGRAM

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            //위에 있는 hlsl을 가져온 거 같은데 한번 확인해 보자

            ENDHLSL
        }

        Pass//Depth 그리는 Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Blend SrcAlpha OneMinusSrcAlpha//블렌드 스타일 적용해보기(다만 현재 Pass에서 alpha값을 변경하는게 아니라 변화 없음)
            Cull Front 

             HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}