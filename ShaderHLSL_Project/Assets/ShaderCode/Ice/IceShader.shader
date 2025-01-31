Shader "ShaderCode/Ice"
{
    
    Properties
    { 
        [BaseMap]_MainTex("Base Map",2D) = "white"{}
        [Normal]_NormalMap("Normal Map",2D) = "bump"{}
        [BaseColor][HDR]_BaseColor("Base Color",color) = (1,1,1,1)

        [Header(Refraction Setting)]
        _RefractNormalAmount("Refraction Normal Amount",Range(0,1)) = 0.2
        _RefractionAmount("Refraction Amount",Range(0,1)) = 0.7

        [Header(Ice Setting)]//Ice 관련 변수들
        [Space(5)]
        [HDR]_IceColor("Ice Color",color) = (1,1,1,1)
        _IceTex("Ice Texture",2D) = "white"{}

        [Space(5)]
        _IceDepth("Ice Depth Value",Range(0,1)) = 0.5

        [Space(5)]
        _IceOffset2("Ice 2 Offset",vector) = (1,1,0,0)
        _IceDepth2("Ice 2 Depth",Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags { 
            "RenderType" = "Opaque"
            "Queue" = "Transparent-1"//Opaque Texture를 사용하기 위해 큐 변경
            "RenderPipeline" = "UniversalRenderPipeline" 
            }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //그림자 멀티 컴파일
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE 
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //Opaque Texture를 사용하기 위한 인클루드
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

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

                float3 normal       : TEXCOORD2;
                float3 tangent      : TEXCOORD3;
                float3 bitangent    : TEXCOORD4;

                //float3 viewDirWS    : TEXCOORD5;
            };

            //라이트 계산할 때 사용하는 구조체 변수
            struct lightData
            {  
                float3 normal;

                //float3 albedo;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
  
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            TEXTURE2D(_IceTex);
            SAMPLER(sampler_IceTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NormalMap_ST;

                float _RefractNormalAmount;
                float _RefractionAmount;

                float4 _IceTex_ST;
                //float4 _IceTex_TexelSize;

                float _IceDepth;

                float4 _IceOffset2;
                float _IceDepth2;

                float4 _BaseColor;
                float4 _IceColor;
                
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);

                OUT.positionHCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;

                OUT.uv = IN.uv;

                //유니티가 제공해주는 노멀 계산 함수 사용
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normal = normalize(normalInput.normalWS);
                OUT.tangent = normalize(normalInput.tangentWS);
                OUT.bitangent = normalize(normalInput.bitangentWS);
                
                //OUT.viewDirWS = normalize(_WorldSpaceCameraPos - vertexInput.positionWS);

                return OUT;
            }

            //노멀맵으로 노멀 계산
            float3 CalculateNormal(float2 normalUV , float3x3 _TBN)
            {
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV);
                float3 normalMap_compressed = UnpackNormal(normalMap);

                return mul(normalMap_compressed,_TBN);
            }

            float3 CalculateLighting(lightData data, Light light)
            {
                float _NdotL = saturate(dot(data.normal,light.direction));

                return _NdotL * light.shadowAttenuation * light.distanceAttenuation * light.color;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //카메라 방향 계산
                float3 viewDir = normalize(_WorldSpaceCameraPos - IN.positionWS);

                //노멀 계산
                float2 normalUV = TRANSFORM_TEX(IN.uv,_NormalMap);

                float3x3 TBN = float3x3
                (
                    IN.tangent,
                    IN.bitangent,
                    IN.normal
                );

                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV);
                float3 normalMap_compressed = UnpackNormal(normalMap);

                float3 normal = mul(normalMap_compressed,TBN);

                //텍스쳐 불러오기
                float2 textureUV = TRANSFORM_TEX(IN.uv,_MainTex);
                float4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,textureUV);

                //Volumatric Ice Rendering 계산
                //https://www.youtube.com/watch?v=G-5bhff4f-M&t=929s

                //Ice 렌더링을 위해 tangent space view 계산 (TransformWorldToTangentDir 함수 새롭게 배웠다)
                float3 tangentView = TransformWorldToTangent(viewDir,TBN);
                //float3 tangentView = float3(
                //    dot(viewDir,IN.tangent),
                //    dot(viewDir,IN.bitangent),
                //    dot(viewDir,IN.normal)
                //    );

                float3 reflectView = reflect(-tangentView,normalMap_compressed);
                //iceUV += reflectView.xy * (_IceDepth / abs(reflectView.z)) / _IceTex_TexelSize.z;

                
                float2 iceUV = TRANSFORM_TEX(IN.uv,_IceTex);

                //첫번째 Ice 텍스쳐 가져오기
                float2 iceUV1 = iceUV + reflectView.xy / abs(reflectView.z) * _IceDepth;
                float4 iceNoise1 = SAMPLE_TEXTURE2D(_IceTex,sampler_IceTex,iceUV1);
                
                //두번째 Ice 텍스쳐 가져오기
                float2 iceUV2 = (iceUV * _IceOffset2.xy + _IceOffset2.zw) + reflectView.xy / abs(reflectView.z) * _IceDepth2;
                float4 iceNoise2 = SAMPLE_TEXTURE2D(_IceTex,sampler_IceTex,iceUV2);

                //두 텍스쳐 결합
                float4 finalIceNoise = (iceNoise1 * (1 - _IceDepth) + iceNoise2 * (1 - _IceDepth2)) / (2 - _IceDepth - _IceDepth2 + 0.001);


                float3 lightColor = float3(0,0,0);

                lightData data = (lightData)0;
                data.normal = normal;

                //Main Light 계산
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                lightColor += CalculateLighting(data,mainLight);

                //Ambient 적용
                lightColor += SampleSH(normal);

                //투과 이미지 제작
                float2 refrectUV = GetNormalizedScreenSpaceUV(IN.positionHCS) + TransformWorldToViewDir(normal) * _RefractNormalAmount;
                float3 refractCol =  SampleSceneColor(refrectUV);

                float3 baseCol = lerp(albedo,refractCol,_RefractionAmount) * _BaseColor;

                //전체 라이팅 계산
                float4 col = lerp(float4(baseCol,1),_IceColor,1 - finalIceNoise);
                col.rgb *= lightColor;

                return col;

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