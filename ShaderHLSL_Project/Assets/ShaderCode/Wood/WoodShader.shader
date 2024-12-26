//Ray Marching을 사용한 조각나는 나무
Shader "ShaderCode/Wood"
{
    Properties
    {
        _MainTex("Wood Texture",2D) = "white" {}
        _PlaneTex("Wood Trunk Texture",2D) = "while"{}
        _Edge("Edge",Range(-1,1)) = 0.0
        _Color("Wood Color",Color) = (1,1,1,1)
    }

    SubShader
    {
        
        Cull off

        Tags { 
            "RenderType" = "Opaque"
            "Queue" = "AlphaTest"//alpha clip을 사용하기 때문에 alpha clip에 넣어줌
            "RenderPipeline" = "UniversalRenderPipeline" 
        }
        
        Pass
        {

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            

            struct Attributes
            {
                
                float4 positionOS   : POSITION;     
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {

                float4 positionHCS  : SV_POSITION;
                float4 positionOS   : TEXCOORD0;

                float2 uv           : TEXCOORD1;
            };            

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_PlaneTex);
            SAMPLER(sampler_PlaneTex);

            CBUFFER_START(Unity_PerMaterial)
                float4 _MainTex_ST;
                float4 _PlaneTex_ST;
                float _Edge;
                float4 _Color;
            CBUFFER_END

            //Ray Marchind때 사용할 매크로 변수들
            #define MAX_MARCHING_STEPS 60
            #define MAX_DISTANCE 10
            #define SURFACE_DISTANCE 0.001

            //간단한 평면 SDF
            float planeSDF(float3 pos){
                float plane = pos.y - _Edge;
                return plane;
            }

            float RayMarching(float3 ray_origin,float3 ray_dir){
                float dis = 0;

                for(int i = 0; i< MAX_MARCHING_STEPS;i++){
                    //Ray 위치 계산
                    float3 ray_pos = ray_origin + ray_dir * dis;

                    //평면까지의 거리 계산
                    float plane = planeSDF(ray_pos);

                    //평면까지의 거리를 Ray 거리에 누적
                    dis += plane;

                    //Ray가 벽에 부디쳤을 경우 또는 너무 멀리 간 경우 나가기
                    if(plane < SURFACE_DISTANCE || dis > MAX_DISTANCE) break;
                }

                return dis;
            }

            Varyings vert(Attributes IN)
            {

                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionOS = IN.positionOS;

                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);

                return OUT;
            }

          
            half4 frag(Varyings IN, bool face : SV_ISFRONTFACE) : SV_Target
            {

                //Edge보다 높은 곳은 Cutoff
                if(IN.positionOS.y > _Edge) discard;

                //Ray 의 시작점과 방향 계산(Object Space에서 계산)
                float3 ray_origin = TransformWorldToObject(_WorldSpaceCameraPos);
                //float3 ray_origin = float3(10,10,0);
                float3 ray_dir = normalize(IN.positionOS - ray_origin);

                //Ray 최종 지점 구하기
                float dis = RayMarching(ray_origin,ray_dir);
                float3 ray_finalPos = ray_origin + ray_dir * dis;

                //최종 지점의 xz좌표로 uv 생성
                float2 ray_uv = ray_finalPos.xz;
                float4 planeColor = SAMPLE_TEXTURE2D(_PlaneTex,sampler_PlaneTex,ray_uv + 0.5);

                half4 woodColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,IN.uv) * _Color;

                //return half4(ray_finalPos,1);
                return face ? half4(woodColor.rgb,1) : half4(planeColor);
            }
            ENDHLSL
        }

        Pass//그림자 패스
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

             HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                
                float4 positionOS   : POSITION;      
            };

            struct Varyings
            {
            
                float4 positionCS   : SV_POSITION;
                float4 positionOS   : TEXCOORD0;   

            };     
            


            CBUFFER_START(Unity_PerMaterial)
                float _Edge;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

               OUT.positionCS = TransformObjectToHClip(IN.positionOS);
               OUT.positionOS = IN.positionOS;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {

                if(IN.positionOS.y > _Edge) discard;

                return 0;
            }

            ENDHLSL
        }

        Pass//뎁스 패스
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull off

             HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                
                float4 positionOS   : POSITION;      
            };

            struct Varyings
            {
            
                float4 positionCS   : SV_POSITION;
                float4 positionOS   : TEXCOORD0;   

            };     
            


            CBUFFER_START(Unity_PerMaterial)
                float _Edge;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

               OUT.positionCS = TransformObjectToHClip(IN.positionOS);
               OUT.positionOS = IN.positionOS;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {

                if(IN.positionOS.y > _Edge) discard;

                return 0;
            }

            ENDHLSL
        }
    }
}