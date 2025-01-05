Shader "ShaderCode/ScreenSpaceShader"
{    
    // The _BaseColor variable is visible in the Material's Inspector, as a field 
    // called Base Color. You can use it to select a custom color. This variable
    // has the default value (1, 1, 1, 1).
    Properties
    { 
        _MainTex("Main Texture",2D) = "white"{}
        [HDR]_ToonColor("Toon Color", Color) = (1, 1, 1, 1)

        _FrensalPower("Frensal Power",Range(1.0,10.0)) = 1.0
        _ShadowPower("Shadow Power",Range(0,1)) = 0.5
        _ToonValue("Toon Value",Range(0,1)) = 0.1
    }

    SubShader
    {        
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"         

            struct Attributes
            {
                float4 positionOS   : POSITION;   
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;       
                
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                //float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float4 screenPos : TEXCOORD4;

            };

            // To make the Unity shader SRP Batcher compatible, declare all
            // properties related to a Material in a a single CBUFFER block with 
            // the name UnityPerMaterial.

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
            float4 _ToonColor;
            float _FrensalPower;
            float _ShadowPower;
            float _ToonValue;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                OUT.normal = TransformObjectToWorldNormal(IN.normal);

                OUT.viewDir = normalize(_WorldSpaceCameraPos - TransformObjectToWorld(IN.positionOS.xyz));

                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                
                IN.normal = normalize(IN.normal);
                IN.viewDir = normalize(IN.viewDir);

                float NoV = saturate(dot(IN.viewDir,IN.normal));
                //float frensal = _FrensalPower + (1 - _FrensalPower) * pow(1 - NoV, 5);//외곽 프레넬 계산
                float frensal =pow(1 - NoV, _FrensalPower);//외곽 프레넬 계산

                //하프 렘버프 방식 라이트 계산
                Light lightInfo = GetMainLight();
                float halfNdotL = dot(IN.normal,lightInfo.direction) * 0.5 + 0.5;
                halfNdotL = saturate(halfNdotL);
                
                half2 sUV = IN.screenPos.xy / IN.screenPos.w;

                half4 col;
                col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, sUV + half2(0, _Time.y * 0.1));
                //col = half4(ss,0,1);
                

                col = ((1 - halfNdotL) * _ShadowPower + frensal)> _ToonValue ? _ToonColor : col;// 프레넬과 그림자 부분에 툰 색을 적용하고 그 나머진 테스트 색 적용

                return col;
                
            }
            ENDHLSL
        }
        //UsePass "Universal Render Pipeline/Lit/ShadowCaster"다른 쉐이더의 패스를 가져올 수 있음
        Pass//또는 이렇게 새로운 패스를 만들고 이미 만들어진 hlsl 셰이더를 가져올 수 있다
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
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