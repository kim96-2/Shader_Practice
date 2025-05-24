Shader "ShaderCode/HalfTone"
{
    // The _BaseMap variable is visible in the Material's Inspector, as a field
    // called Base Map.
    Properties
    { 
        _MainTex("Base Map", 2D) = "white"{} 

        [Space(10)]
        [Normal]_NormalMap("Normal Map",2D) = "bump"{}

        [Space(10)]
        _MainColor("Base Color",Color) = (1,1,1,1)
        _ShadowColor("Shadow Color", Color) = (0,0,0,0)

        [Space(10)]
        [Header(Specular Setting)]
        [HDR]_SpecColor("Specular Color",Color) = (1,1,1,1)
        _SpecPower("Specular Power",float) = 10
        _SpecSmoothness("Specular Smoothness",Range(0, 1)) =0.01
        _SpecStep("Specular Step", Range(0, 1)) = 0.9

        [Space(15)]
        _VoronoiDensity("Voronoi Density", Float) = 5
        _VoronoiRotate("Voronoi Rotate Amount", Range(0, 360)) = 0

        [Space(15)]
        _FallOut("FallOut Treshold", Range(0, 1)) = 0.5
        _Lit("Lit Threshold",Range(0, 1)) = 0.5 

        [Space(15)]
        _OutlineSize("Outline Size", Float) = 0.5
        _OutlineColor("Outline Color", Color) = (1,1,1,1)

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

                //test
                float3 normalOS     : TEXCOORD3;
                float4 tangentOS    : TEXCOORD4;

                float4 positionSS    : TEXCOORD5;
            };

            //커스텀 라이팅을 계산할 때 사용할 구조체
            struct CustomlightingData
            {
                float3 positionWS;
                float3 viewDir;
                float3 normal;
                //float4 shadowCoord;

                float3 albedo;

                float VoronoiValue;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
                
                float4 _MainTex_ST;

                float4 _NormalMap_ST;

                half4 _MainColor;
                half4 _ShadowColor;

                float4 _SpecColor;
                float _SpecPower;
                float _SpecSmoothness;
                float _SpecStep;

                float _VoronoiDensity;
                half _VoronoiRotate;

                float _FallOut;
                float _Lit;
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

                OUT.normalOS = IN.normalOS;
                OUT.tangentOS = IN.tangentOS;

                OUT.positionSS = ComputeScreenPos(OUT.positionHCS);

                return OUT;
            }

            float Remap(float4 In, float InMin, float InMax, float OutMin, float OutMax)
            {
                return OutMin + (In - InMin) * (OutMax - OutMin) / (InMax - InMin);
            }

            inline float2 unity_voronoi_noise_randomVector (float2 UV, float offset)
            {
                float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
                UV = frac(sin(mul(UV, m)) * 46839.32);
                return float2(sin(UV.y*+offset)*0.5+0.5, cos(UV.x*offset)*0.5+0.5);
            }

            void Unity_Voronoi_float(float2 UV, float AngleOffset, float CellDensity, out float Out)
            {
                float2 g = floor(UV * CellDensity);
                float2 f = frac(UV * CellDensity);
                float t = 8.0;
                float3 res = float3(8.0, 0.0, 0.0);

                for(int y=-1; y<=1; y++)
                {
                    for(int x=-1; x<=1; x++)
                    {
                        float2 lattice = float2(x,y);
                        float2 offset = unity_voronoi_noise_randomVector(lattice + g, AngleOffset);
                        float d = distance(lattice + offset, f);
                        if(d < res.x)
                        {
                            res = float3(d, offset.x, offset.y);
                            Out = res.x;
                            //Cells = res.y;
                        }
                    }
                }
            }

            float2 Unity_Rotate_Degrees_float(float2 UV, float2 Center, float Rotation)
            {
                Rotation = Rotation * (3.1415926f/180.0f);
                UV -= Center;
                float s = sin(Rotation);
                float c = cos(Rotation);
                float2x2 rMatrix = float2x2(c, -s, s, c);
                rMatrix *= 0.5;
                rMatrix += 0.5;
                rMatrix = rMatrix * 2 - 1;
                UV.xy = mul(UV.xy, rMatrix);
                UV += Center;
                return UV;
            }

            //라이팅 계산해줄 함수
            half3 CustomLightHandler(CustomlightingData data, Light light){

                float3 lightColor = light.color;

                float NdotL = dot(data.normal,light.direction);//현실적인 lambert 
                float halfNdotL = NdotL * 0.5 + 0.5;//half lambart

                //원래 이렇게 atten 계산하면 안되지만... 우선 예쁜 사진을 위하여...
                float atten = light.distanceAttenuation * light.shadowAttenuation;
                atten = NdotL > 0 ? atten : 1;

                float gradient = 0;
                gradient = smoothstep(_Lit - _FallOut, _Lit +_FallOut, 1 - halfNdotL);
                gradient = smoothstep(gradient, gradient + 0.01, data.VoronoiValue);

                gradient *= atten;

                float spec = saturate(dot(data.normal,normalize(light.direction + data.viewDir)));//blinn Phong
                spec = pow(spec,_SpecPower) * (light.distanceAttenuation);
                spec = smoothstep(_SpecStep, _SpecStep + _SpecSmoothness, spec);
                spec = smoothstep(spec, spec + 0.01, data.VoronoiValue);
                spec = 1 - spec;
                spec *= gradient;

                half3 col = 0;

                col = lerp(_ShadowColor.rgb, _MainColor.rgb, gradient);
                col = lerp(col, _SpecColor, spec);

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

                //화면 좌표 비율 늘어나지 않게 적용
                float2 screenPos = IN.positionSS.xy / IN.positionSS.w;
                screenPos.y /= _ScreenParams.x / _ScreenParams.y;

                screenPos *= _VoronoiDensity;
                screenPos = Unity_Rotate_Degrees_float(screenPos, float2(0.5, 0.5), _VoronoiRotate);

                Unity_Voronoi_float(screenPos, 0, 5, data.VoronoiValue);

                //data.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                data.albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb;
                
                float3 col = 0;
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);

                //메인 라이트 받기 shadowCoord
                Light mainLight = GetMainLight(shadowCoord);
                col += CustomLightHandler(data,mainLight);

                /*
                //추가적 라이트 받기
                uint additionalLightCount = GetAdditionalLightsCount();
                data.basicLight = 0;//기본 밝기 꺼주기
                for(uint i = 0; i < additionalLightCount; i++){
                    Light additionalLight = GetAdditionalLight(i,IN.positionWS);
                    //additionalLight.shadowAttenuation = AdditionalLightRealtimeShadow(i,IN.positionWS,additionalLight.direction);//추가적 라이트 그림자 받기 위한 끄적임
                    additionalLight.shadowAttenuation = saturate(additionalLight.shadowAttenuation);//그림자 세기 강제적으로 약하게 해보기
                    col += CustomLightHandler(data,additionalLight);
                }
                */

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