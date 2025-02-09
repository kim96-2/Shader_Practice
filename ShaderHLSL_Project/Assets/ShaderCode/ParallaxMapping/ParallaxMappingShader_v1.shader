Shader "ShaderCode/ParallaxMapping_v1"
{
    
    Properties
    { 
        [BaseColor]_BaseColor("Background Color",color) = (0,0,0,0)

        [Header(Background Setting)]
        _BackgroundCubeMap("Background Cube Map",Cube) = "white"{}

        [Header(Layer Setting)]
        _LayerCounts("Layer Counts",int) = 4
        _LayerTex("Layer Textures",2DArray) = "black" {}

        _LayerOffset("Layer Start Offset",Range(0,1)) = 0.1
        
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

            TEXTURECUBE(_BackgroundCubeMap);
            SAMPLER(sampler_BackgroundCubeMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;

                int _LayerCounts;
                float _LayerOffset;
                
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

            //배경화면을 위한 Interior Mapping
            //공식을 가져온 사이트: https://discussions.unity.com/t/interior-mapping/635709/10
            float4 InteriorMapping(float2 uv, float3 view)
            {
                float2 roomUV = frac(uv);

                view = -view;

                float3 pos = float3(roomUV * 2.0 - 1.0, 1.0);
                float3 id = 1.0 / view;
                float3 k = abs(id) - pos * id;
                float kMin = min(min(k.x, k.y), k.z);
                pos += kMin * view;

                return SAMPLE_TEXTURECUBE(_BackgroundCubeMap,sampler_BackgroundCubeMap,pos);
            }

            float4 SampleLayerTexture(int layerNum, float layerDepth,float2 uv,float3 view)
            {
                float2 layerUV = uv + view.xy / view.z * layerDepth;

                if(layerUV.x > 1 || layerUV.x < 0) return 0;
                if(layerUV.y > 1 || layerUV.y < 0) return 0;

                return SAMPLE_TEXTURE2D_ARRAY(_LayerTex, sampler_LayerTex, layerUV, layerNum);
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
                //float3 tangentView = float3(
                //    dot(viewDir,IN.tangent),
                //    dot(viewDir,IN.bitangent),
                //    dot(viewDir,IN.normal)
                //    );
                float3 reflectView = reflect(-tangentView,float3(0,0,1));

                float4 finalCol = _BaseColor;

                finalCol = AlphaBlend(InteriorMapping(IN.uv,tangentView),finalCol);

                int layerNum = _LayerCounts;
                for(int i = layerNum - 1 ; i >=0 ; i --){
                    finalCol = AlphaBlend(
                                SampleLayerTexture(i,(1.0 -  (float)(layerNum - i) /layerNum) * (1 - _LayerOffset) + _LayerOffset,IN.uv,reflectView),
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