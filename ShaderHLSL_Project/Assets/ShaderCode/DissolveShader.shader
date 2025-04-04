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
            "RenderType" = "Transparent"
            "Queue" = "AlphaTest"//alpha clip을 사용하기 때문에 alpha clip에 넣어줌
            "RenderPipeline" = "UniversalRenderPipeline" 
        }

        Pass
        {
            
            ZWrite On 
            //Cull Front

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

                clip(noiseCutoff_1 - 0.5);//여기서 alpha cliping중

                return customColor;
            }
            ENDHLSL
        }

        Pass//새로운 쉐도우 패스 만들어줌
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            //Blend SrcAlpha OneMinusSrcAlpha//블렌드 스타일 적용해보기(다만 현재 Pass에서 alpha값을 변경하는게 아니라 변화 없음)
            Cull Back

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                
                float4 positionOS   : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;           
            };

            struct Varyings
            {
            
                float4 positionCS  : SV_POSITION;
                float4 positionOS : TEXCOORD0;
                //float2 uv : TEXCOORD1;
                float2 noiseUV : TEXCOORD2;

            };     
            
            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            CBUFFER_START(Unity_PerMaterial)
                float4 _NoiseTex_ST;
                half _CutoffHeight,_GlowSize,_NoisePower;
            CBUFFER_END

            //float3 _LightDirection;

            float4 GetShadowCasterPositionCS(float3 positionWS, float3 normalWS) {

                //float3 lightDirectionWS = _LightDirection;
	            float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _MainLightPosition.xyz));
#if UNITY_REVERSED_Z
	            positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
	            positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif
	            return positionCS;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normInputs = GetVertexNormalInputs(IN.normalOS);

                OUT.positionCS = GetShadowCasterPositionCS(posInputs.positionWS,normInputs.normalWS);
                OUT.positionOS = IN.positionOS;

                OUT.noiseUV = TRANSFORM_TEX(IN.uv,_NoiseTex);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {

                //첫번째 패스에서 했던 그대로 alpha 값 적용
                float noiseCutoff_1;
                float noiseCutoff_2 = (SAMPLE_TEXTURE2D(_NoiseTex,sampler_NoiseTex ,IN.noiseUV)).x;

                //noiseCutoff_2를 (0,1)에서 (-noisePower,noisePower)로 remap시킴
                noiseCutoff_2 = -_NoisePower + (noiseCutoff_2)*(_NoisePower * 2); 
                noiseCutoff_2 +=_CutoffHeight;

                //noise 외곽 공간 계산
                noiseCutoff_1 = step(IN.positionOS.y,noiseCutoff_2 + _GlowSize);
                noiseCutoff_2 = step(IN.positionOS.y,noiseCutoff_2);

                clip(noiseCutoff_1 - 0.5);//여기서 alpha cliping중

                return 0;
            }


            ENDHLSL
        }

        Pass//Depth 그리는 Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            //Blend SrcAlpha OneMinusSrcAlpha//블렌드 스타일 적용해보기(다만 현재 Pass에서 alpha값을 변경하는게 아니라 변화 없음)
            Cull Back

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