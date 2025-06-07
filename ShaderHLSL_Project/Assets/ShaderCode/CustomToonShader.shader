Shader "ShaderCode/CustomToon"
{
    // The _BaseMap variable is visible in the Material's Inspector, as a field
    // called Base Map.
    Properties
    { 
        _MainTex("Base Map", 2D) = "white"{}
        _MainColor("Base Color",Color) = (1,1,1,1)

        [Space(10)]
        [Normal]_NormalMap("Normal Map",2D) = "bump"{}

        [Space(10)]
        [Header(Specular Setting)]
        [HDR]_SpecColor("Specular Color",Color) = (1,1,1,1)
        _SpecPower("Specular Power",float) = 10
        _SpecSmoothness("Specular Smoothness",float) = 3

        [Space(15)]
        _BasicLight("Default Light",Color) = (0.5,0.5,0.5,1)

        _ToonValue("Toon Shadow Value",Range(0,1)) = 0.3
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            
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
                float4 tangentOS    : TANGENT;//노멀맵 계산용 Tangent
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionWS   : TEXCOORD0;

                float2 uv           : TEXCOORD1;
                float3 viewDir      : TEXCOORD2;
                float3 normal       : TEXCOORD3;
                float3 tangent      : TEXCOORD4;
                float3 bitangent    : TEXCOORD5;

                //test
                float3 normalOS     : TEXCOORD6;
                float4 tangentOS    : TEXCOORD7;
            };

            //커스텀 라이팅을 계산할 때 사용할 구조체
            struct CustomlightingData
            {
                float3 positionWS;
                float3 viewDir;
                float3 normal;
                //float4 shadowCoord;

                float3 albedo;
                float3 basicLight;

                
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
                
                float4 _MainTex_ST;

                float4 _NormalMap_ST;

                float4 _MainColor;

                float4 _SpecColor;
                float _SpecPower;
                float _SpecSmoothness;

                float4 _BasicLight;

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

                //OUT.normal = normalize(TransformObjectToWorldNormal(IN.normalOS));
                //OUT.tangent = normalize(TransformObjectToWorldDir(IN.tangentOS.xyz));
                //OUT.bitangent = normalize(cross(OUT.normal , OUT.tangent) * IN.tangentOS.w);

                
                //유니티가 제공해주는 노멀 계산 함수 사용
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normal = normalize(normalInput.normalWS);
                OUT.tangent = normalize(normalInput.tangentWS);
                OUT.bitangent = normalize(normalInput.bitangentWS);

                OUT.normalOS = IN.normalOS;
                OUT.tangentOS = IN.tangentOS;

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


                //float3 color = data.albedo * ( data.basicLight + lightColor * NdotL);
                float3 col = data.albedo * lerp(data.basicLight,lightColor,NdotL);
                //color = color + smoothstep(0,1,NdotL * spec) * ( float3(1,1,1) * lightColor - color);
                col = col + NdotL * spec * _SpecColor * light.color;

                return col;

            }

            half4 frag(Varyings IN) : SV_Target
            {
                // The SAMPLE_TEXTURE2D marco samples the texture with the given
                // sampler.

                //라이팅을 위한 데이터 묶어주기
                CustomlightingData data;
                data.positionWS = IN.positionWS;

                //data.normal = normalize(IN.normal);

                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,IN.uv);
                float3 normal_compressed = UnpackNormal(normalMap);

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                float3x3 TBN = float3x3
                (
                    normalInput.tangentWS,
                    normalInput.bitangentWS,
                    normalInput.normalWS
                );

                data.normal = mul(normal_compressed,TBN);
                //data.normal = normal_compressed;

                data.viewDir = normalize(IN.viewDir);

                //data.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                data.albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb * _MainColor.rgb;
                data.basicLight = _BasicLight.rgb;
                
                float3 col = 0;
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);

                //메인 라이트 받기 shadowCoord
                Light mainLight = GetMainLight(shadowCoord);
                //return mainLight.shadowAttenuation;
                col += CustomLightHandler(data,mainLight);

                //추가적 라이트 받기
                uint additionalLightCount = GetAdditionalLightsCount();
                data.basicLight = 0;//기본 밝기 꺼주기
                for(uint i = 0; i < additionalLightCount; i++){
                    Light additionalLight = GetAdditionalLight(i,IN.positionWS);
                    additionalLight.shadowAttenuation = AdditionalLightRealtimeShadow(i,IN.positionWS,additionalLight.direction);//추가적 라이트 그림자 받기 위한 끄적임
                    additionalLight.shadowAttenuation = saturate(additionalLight.shadowAttenuation);//그림자 세기 강제적으로 약하게 해보기
                    col += CustomLightHandler(data,additionalLight);
                }
                
                //return half4(data.normal,1);
                return half4(col,1);
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