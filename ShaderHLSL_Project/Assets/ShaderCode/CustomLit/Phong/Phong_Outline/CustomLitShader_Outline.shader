//2025-02-06 : 위 쉐이더를 Phong Shading 계산 법으로 변경함과 동시에 정리 진행
Shader "ShaderCode/CustomLit_Outline"
{    
    Properties
    { 
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _MainTex("Main Texture",2D) = "white"{}
        _NormalMap("NormalMap Texture",2D) = "bump"{}

        [Space(10)]
        [Header(Specular Setting)]
        _SpecPower("Specular Power",float) = 10

        [Space(10)]
        [Header(Outline Setting)]
        _OutlineSize("Outline Size",float) = 1
        [HDR]_OutlineColor("Outline Color",color) = (1,1,1,1)
    }

    SubShader
    {        
        
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {            
            Name "UniversalForward"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //그림자와 추가적 라이트를 위한 선언
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE 
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"         

            struct Attributes
            {
                float4 positionOS   : POSITION;   
                float2 uv           : TEXCOORD0;
                float3 normal       : NORMAL;       
                float4 tangentOS    : TANGENT;//노멀맵 계산용 Tangent
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 viewDir      : TEXCOORD1;
                float fogCoord      : TEXCOORD2;

                float3 positionWS   : TEXCOORD3;

                //NormalMap 계산용
                float3 normal       : TEXCOORD4;
                float3 tangent      : TEXCOORD5;
                float3 bitangent    : TEXCOORD6;
            };

            //라이팅 계산할 때 필요한 변수들 정리한 구조체 변수
            struct CustomLightingData
            {
                float3 normal;
                float3 viewDir;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
                // The following line declares the _BaseColor variable, so that you
                // can use it in the fragment shader.
                float4 _MainTex_ST;
                float4 _NormalMap_ST;

                half4 _BaseColor;       
                float _SpecPower;     
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                
                //OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionHCS = vertexInput.positionCS;
                //OUT.uv = TRANSFORM_TEX(IN.uv , _MainTex);
                OUT.uv = IN.uv;
                OUT.normal = TransformObjectToWorldNormal(IN.normal);

                OUT.viewDir = normalize(_WorldSpaceCameraPos - vertexInput.positionWS);

                OUT.positionWS = vertexInput.positionWS;
                //OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);

                OUT.fogCoord = ComputeFogFactor(OUT.positionHCS.z);

                //유니티가 제공해주는 노멀 계산 함수 사용
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normal, IN.tangentOS);
                OUT.normal = normalize(normalInput.normalWS);
                OUT.tangent = normalize(normalInput.tangentWS);
                OUT.bitangent = normalize(normalInput.bitangentWS);
                

                return OUT;
            }

            float3 CaculateLighting(CustomLightingData data, Light light)
            {
                float NdotL = saturate(dot(data.normal,light.direction));

                float NdotH = saturate(dot(data.normal,normalize(light.direction + data.viewDir)));//blinn Phong
                float spec = pow(NdotH,_SpecPower) * NdotL;

                //return light.shadowAttenuation;
                return light.color * light.distanceAttenuation * light.shadowAttenuation * (NdotL + spec);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                IN.viewDir = normalize(IN.viewDir);

                //노멀맵 계산
                float2 normalMapUV = TRANSFORM_TEX(IN.uv , _NormalMap);
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalMapUV);
                float3 normal_compressed = UnpackNormal(normalMap);

                float3x3 TBN = float3x3
                (
                    normalize(IN.tangent),
                    normalize(IN.bitangent),
                    normalize(IN.normal)
                );
                float3 normalWS = mul(normal_compressed,TBN);

                //라이트 계산을 위한 변수들 정리
                CustomLightingData data = (CustomLightingData)0;
                data.viewDir = IN.viewDir;
                data.normal = normalWS;

                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);

                float3 lightColor = 0;

                //메인 라이트 계산
                Light mainLight = GetMainLight(shadowCoord);
                lightColor += CaculateLighting(data,mainLight);

                //추가적 라이트 계산
                uint additionalLightCount = GetAdditionalLightsCount();
                for(uint i = 0; i < additionalLightCount; i++)
                {
                    Light additionalLight = GetAdditionalLight(i,IN.positionWS);
                    additionalLight.shadowAttenuation = AdditionalLightRealtimeShadow(i,IN.positionWS,additionalLight.direction);

                    lightColor += CaculateLighting(data,additionalLight);
                }

                float2 mainTexUV = TRANSFORM_TEX(IN.uv , _MainTex);
                half4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV) * _BaseColor;
                
                col.rgb *= SampleSH(normalWS) + lightColor;

                //color.rgb = MixFog(color.rgb,IN.fogCoord);

                return col;
                
            }
            ENDHLSL
        }
        //UsePass "Universal Render Pipeline/Lit/ShadowCaster"//다른 쉐이더의 패스를 가져올 수 있음
        Pass//또는 이렇게 새로운 패스를 만들고 이미 만들어진 hlsl 셰이더를 가져올 수 있다
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 

            

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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 

            #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        pass
        {
            Name "Outline"
            Tags
            {
                "LightMode" = "Outline"
            }

            ZWrite Off
            ZTest LEqual
            Cull front

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 

            CBUFFER_START(UnityPerMaterial)
                // The following line declares the _BaseColor variable, so that you
                // can use it in the fragment shader.
                float4 _MainTex_ST;
                float4 _NormalMap_ST;

                half4 _BaseColor;       
                float _SpecPower;    
                
                float _OutlineSize;
                float4 _OutlineColor;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;   
                float3 normal       : NORMAL;       

            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float4 pos = IN.positionOS + float4(IN.normal * _OutlineSize,0);

                OUT.positionHCS = TransformObjectToHClip(pos.xyz);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return _OutlineColor;
            }

            ENDHLSL
        }

    }
}