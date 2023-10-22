Shader "ShaderCode/CustomToon"
{
    // The _BaseMap variable is visible in the Material's Inspector, as a field
    // called Base Map.
    Properties
    { 
        _MainTex("Base Map", 2D) = "white"{}
        _MainColor("Base Color",Color) = (1,1,1,1)

        _SpecPower("Specular Power",float) = 10
        _SpecSmoothness("Specular Smoothness",float) = 3

        _BasicLight("Default Light",float) = 0.3

        _ToonValue("Toon Shadow Value",Range(0,1)) = 0.3
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //그림자를 위한 멀티 컴파일 키워드(정확히 어떤걸 하는진 더 찾아봐야됨)
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE 
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;

                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionWS   : TEXCOORD0;

                float2 uv           : TEXCOORD1;
                float3 normal       : TEXCOORD2;
                float3 viewDir      : TEXCOORD3;
            };

            //커스텀 라이팅을 계산할 때 사용할 구조체
            struct CustomlightingData
            {
                float3 positionWS;
                float3 viewDir;
                float3 normal;
                //float4 shadowCoord;

                float3 albedo;
                float basicLight;

            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                
                float4 _MainTex_ST;

                float4 _MainColor;

                float _SpecPower;
                float _SpecSmoothness;

                float _BasicLight;

                float _ToonValue;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);

                OUT.positionHCS = vertexInput.positionCS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);

                OUT.positionWS = vertexInput.positionWS;
                OUT.viewDir = normalize(_WorldSpaceCameraPos - vertexInput.positionWS);
                OUT.normal = TransformObjectToWorldNormal(IN.normalOS);

                return OUT;
            }

            //라이팅 계산해줄 함수
            float3 CustomLightHandler(CustomlightingData data, Light light){
                //light.shadowAttenuation =smoothstep(0.1,0.11,light.shadowAttenuation);
                //float3 lightColor = light.color * light.shadowAttenuation * light.distanceAttenuation;
                float3 lightColor = light.color * light.distanceAttenuation;
                //light.shadowAttenuation

                //float NdotL = saturate(dot(data.normal,light.direction) * 0.5 + 0.5);//half lambert
                float NdotL = saturate(dot(data.normal,light.direction));//현실적인 lambert
                //NdotL = saturate((NdotL * light.shadowAttenuation) * 0.5 + 0.5);//그림자 세기까지 더하여 half lambert 로 변환
                //NdotL = pow(NdotL,3);
                NdotL = smoothstep(_ToonValue + 0.0,_ToonValue + 0.005,NdotL * light.shadowAttenuation);
                //NdotL = NdotL > 0.2 ? 1 : 0;

                float spec = saturate(dot(data.normal,normalize(light.direction + data.viewDir)));//blinn Phong
                spec = pow(spec,_SpecSmoothness) * _SpecPower * (light.distanceAttenuation);
                spec = smoothstep(0.98,0.981,spec); 

                //float3 color = data.albedo * ( 0.3 + lightColor * NdotL * (1 + spec) );
                //float3 color = data.albedo * lightColor * NdotL + spec;
                float3 color = data.albedo * ( data.basicLight + lightColor * NdotL);
                color = color + smoothstep(0,1,NdotL * spec) * ( float3(1,1,1) * lightColor - color);


                return color;

            }

            half4 frag(Varyings IN) : SV_Target
            {
                // The SAMPLE_TEXTURE2D marco samples the texture with the given
                // sampler.

                //라이팅을 위한 데이터 묶어주기
                CustomlightingData data;
                data.positionWS = IN.positionWS;
                data.normal = normalize(IN.normal);
                data.viewDir = normalize(IN.viewDir);
                //data.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                data.albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb * _MainColor.rgb;
                data.basicLight = _BasicLight;

                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                float3 color = 0;

                //메인 라이트 받기
                Light mainLight = GetMainLight(shadowCoord);
                color += CustomLightHandler(data,mainLight);

                //추가적 라이트 받기
                uint additionalLightCount = GetAdditionalLightsCount();
                data.basicLight = 0;//기본 밝기 꺼주기
                for(uint i = 0; i < additionalLightCount; i++){
                    Light additionalLight = GetAdditionalLight(i,IN.positionWS);
                    additionalLight.shadowAttenuation = AdditionalLightRealtimeShadow(i,IN.positionWS,additionalLight.direction);//추자적 라이트 그림자 받기 위한 끄적임
                    additionalLight.shadowAttenuation = saturate(additionalLight.shadowAttenuation);//그림자 세기 강제적으로 약하게 해보기
                    color += CustomLightHandler(data,additionalLight);
                }
                

                return half4(color,1);
            }

            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"

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