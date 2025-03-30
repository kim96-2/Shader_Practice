Shader "ShaderCode/ParallaxMapping_v2"
{
    
    Properties
    { 
        [BaseColor]_BaseColor("Background Color",color) = (0,0,0,0)

        [Header(Layer Setting)]
        _LayerCounts("Layer Counts",int) = 4
        _LayerTex("Layer Textures",2DArray) = "black" {}

        _LayerOffset("Layer Start Offset",Range(0,1)) = 0.1

        [Header(Difraction Setting)]
        _RampTex("Ramp Texture", 2D) = "black" {}
        _DifractionNormalMap("Difraction Normal Map", 2D) = "bump"{} 

        _DifractionAmount("Dirfaction Amount", Range(0, 1)) = 0.5
        _DifractionRot("Difraction Rotate Amount", float) = 0
        
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

            TEXTURE2D_ARRAY(_LayerTex);
            SAMPLER(sampler_LayerTex);

            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            TEXTURE2D(_DifractionNormalMap);
            SAMPLER(sampler_DifractionNormalMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;

                int _LayerCounts;
                float _LayerOffset;

                float4 _DifractionNormalMap_ST;

                float _DifractionAmount;
                float _DifractionRot;
                
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
            float4 AlphaBlend(float4 source, float4 destination)
            {
                return float4(source.rgb * source.a + destination.rgb * (1 - source.a),1);
            }

            half4 SoftLightBlend(float4 source, float4 destination)
            {
                return (1 - 2 * destination) * source * source + 2 * destination * source;
            }

            float4 SampleLayerTexture(int layerNum, float layerDepth,float2 uv,float3 view)
            {
                float2 layerUV = uv + view.xy / view.z * layerDepth;

                if(layerUV.x > 1 || layerUV.x < 0) return 0;
                if(layerUV.y > 1 || layerUV.y < 0) return 0;

                return SAMPLE_TEXTURE2D_ARRAY(_LayerTex, sampler_LayerTex, layerUV, layerNum);
            }

            //유니티 shader graph에서 제공하는 rotate 노드 수식
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

                float4 finalCol = _BaseColor;

                float3 reflectViewOS = TransformWorldToObject(reflect(-viewDir, IN.normal));
                //return half4(reflectViewOS * 0.5 + 0.5, 1);
                //return half4(reflectViewTS * 0.5 + 0.5, 1);

                float3 difractionNormalMap = UnpackNormal(SAMPLE_TEXTURE2D(_DifractionNormalMap, sampler_DifractionNormalMap, TRANSFORM_TEX(IN.uv, _DifractionNormalMap)));

                //float2 difractionUV = difractionNormalMap.xy * _DifractionAmount + reflectViewOS.xy;
                float2 difractionUV = difractionNormalMap.xy * _DifractionAmount + reflectViewTS.xy;
                difractionUV += Rotate_Radians(IN.uv + tangentView.xy * _DifractionAmount, float2(0, 0), _DifractionRot);
                
                half3 ramp = SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex, difractionUV).rgb;
                finalCol = SoftLightBlend(half4(ramp, 0), finalCol);

                int layerNum = _LayerCounts;
                for(int i = layerNum - 1 ; i >=0 ; i --){
                    finalCol = AlphaBlend(
                                SampleLayerTexture(i,(1.0 -  (float)(layerNum - i) /layerNum) * pow(_LayerOffset, 0.5),IN.uv,reflectViewTS),
                                finalCol);
                }

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