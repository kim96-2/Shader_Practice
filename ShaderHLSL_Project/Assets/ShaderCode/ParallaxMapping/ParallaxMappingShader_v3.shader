Shader "ShaderCode/ParallaxMapping_v1"
{
    
    Properties
    { 

        [Header(Layer Setting)]
        _LayerTex("Layer Texture",2D) = "black" {}

        _LayerOffset("Layer Start Offset",Range(0,3)) = 0.1

        [Header(Difraction Setting)]
        _RampTex("Ramp Texture", 2D) = "black" {}
        _DifractionAmount("Difraction Amount", Range(0, 1)) = 0.5
        _DifrractionOffset("Diffraction Offset", Range(0, 5)) = 1
        _DiffractionRotation("Diffraction Rotation", float) = 0
        
    }

    SubShader
    {
        Tags { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalRenderPipeline" 
            }

        Pass
        {
            //Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 

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

            TEXTURE2D(_LayerTex);
            SAMPLER(sampler_LayerTex);

            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _LayerTex_ST;

                float4 _RampTex_ST;

                float _LayerOffset;

                float _DifractionAmount;

                float _DifrractionOffset;

                float _DiffractionRotation;
                
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

            //Alpha Blending 수식
            half4 AlphaBlend(half4 source, half4 destination)
            {
                return half4(source.rgb * source.a + destination.rgb * (1 - source.a),1);
            }

            //Alpha Blending 수식(additive)
            half4 AlphaBlend_Additive(half4 source, half4 destination)
            {
                return half4(source.rgb * source.a + destination.rgb,1);
            }

            float2 Rotate_Radians(float2 UV, float2 Center, float Rotation)
            {

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

            float4 SampleLayerTexture(float layerDepth,float2 uv,float3 view)
            {
                float2 layerUV = uv + view.xy / view.z * layerDepth;

                //layerUV.y = layerUV.y > 1.0 ? 0.99 : (layerUV.y < 0.0 ? 0.01 : layerUV.y);
                layerUV.x = frac(layerUV.x);

                return SAMPLE_TEXTURE2D(_LayerTex, sampler_LayerTex, layerUV);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //카메라 방향 계산
                float3 viewDir = normalize(_WorldSpaceCameraPos - IN.positionWS);

                float3x3 TBN = float3x3
                (
                    IN.tangent,
                    IN.bitangent,
                    IN.normal
                );

                float3 tangentView = TransformWorldToTangent(viewDir,TBN);

                float3 reflectViewTS = reflect(-tangentView,float3(0,0,1));

                float4 finalCol = 0;

                finalCol = SampleLayerTexture(_LayerOffset, TRANSFORM_TEX(IN.uv, _LayerTex), reflectViewTS);


                float2 difractionUV = 0;
                difractionUV += TRANSFORM_TEX(IN.uv, _RampTex) +  + reflectViewTS.xy / reflectViewTS.z * _DifrractionOffset;
                difractionUV = Rotate_Radians(difractionUV, float2(0, 0) , _DiffractionRotation);
                
                half4 ramp = SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex, difractionUV);
                ramp.a *= _DifractionAmount;
                //finalCol.rgb += ramp * _DifractionAmount;
                //finalCol = AlphaBlend(ramp, finalCol);
                finalCol = AlphaBlend_Additive(ramp, finalCol);

                return finalCol;

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