Shader "ShaderCode/CustomLit"
{    
    // The _BaseColor variable is visible in the Material's Inspector, as a field 
    // called Base Color. You can use it to select a custom color. This variable
    // has the default value (1, 1, 1, 1).
    Properties
    { 
        _MainTex("Main Texture",2D) = "white"{}
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)

        _SpecPower("Specular Power",float) = 10
    }

    SubShader
    {        
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #pragma multi_compile_fog

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
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 lightDir : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
                float fogCoord : TEXCOORD5;
            };

            // To make the Unity shader SRP Batcher compatible, declare all
            // properties related to a Material in a a single CBUFFER block with 
            // the name UnityPerMaterial.

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                // The following line declares the _BaseColor variable, so that you
                // can use it in the fragment shader.
                float4 _MainTex_ST;

                half4 _BaseColor;       
                float _SpecPower;     
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                
                //OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionHCS = vertexInput.positionCS;
                OUT.uv = TRANSFORM_TEX(IN.uv , _MainTex);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);

                OUT.lightDir = normalize(_MainLightPosition.xyz);

                OUT.viewDir = normalize(_WorldSpaceCameraPos - vertexInput.positionWS);

                OUT.shadowCoord = GetShadowCoord(vertexInput);

                OUT.fogCoord = ComputeFogFactor(OUT.positionHCS.z);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                IN.normal = normalize(IN.normal);
                IN.lightDir = normalize(IN.lightDir);//이거 왜한거지...?(테스트 하다가 놔둔건가..)
                IN.viewDir = normalize(IN.viewDir);

                Light lightInfo = GetMainLight(IN.shadowCoord);

                half4 color = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,IN.uv);
                float NdotL = dot(IN.normal,lightInfo.direction);// 하프 램버트 방식으로 라이팅 적용
                NdotL = saturate(NdotL);

                //반사광 계산(Phong)
                //float3 reflectDir = reflect(-lightInfo.direction,IN.normal);
                //half spec = saturate(dot(reflectDir,IN.viewDir));
                

                //반사광 계산(BlinnPhong)
                float3 h = normalize(lightInfo.direction + IN.viewDir);
                half spec = saturate(dot(h,IN.normal));

                spec = pow(spec,_SpecPower);

                half3 ambient = SampleSH(IN.normal);//이부분 정확히 무엇을 하는지 이해 안감


                //NdotL = saturate(NdotL * 0.5 + 0.5);//그림자 값까지 half lambert 계산을 한 렌더링
                //half3 lighting = NdotL * lightInfo.color + ambient;

                half3 lighting = NdotL * lightInfo.color * lightInfo.shadowAttenuation * lightInfo.distanceAttenuation + ambient;

                color.rgb *=lighting;

                color *=_BaseColor;

                color.rgb +=spec * lightInfo.shadowAttenuation * half3(1,1,1);

                color.rgb = MixFog(color.rgb,IN.fogCoord);

                //color.rgb = (lightInfo.shadowAttenuation*0.5 + 0.5) * NdotL * float3(1,1,1);

                return color;
                
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