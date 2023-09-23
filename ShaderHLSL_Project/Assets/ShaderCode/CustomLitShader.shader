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

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                IN.normal = normalize(IN.normal);
                IN.lightDir = normalize(IN.lightDir);
                IN.viewDir = normalize(IN.viewDir);

                Light lightInfo = GetMainLight(IN.shadowCoord);

                half4 color = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,IN.uv);
                float NdotL = saturate(dot(IN.normal,lightInfo.direction) * 0.5 + 0.5);// 하프 램버트 방식으로 라이팅 적용

                //반사광 계산(Phong)
                //float3 reflectDir = reflect(-lightInfo.direction,IN.normal);
                //half spec = saturate(dot(reflectDir,IN.viewDir));
                

                //반사광 계산(BlinnPhong)
                float3 h = normalize(lightInfo.direction + IN.viewDir);
                half spec = saturate(dot(h,IN.normal));

                spec = pow(spec,_SpecPower);

                half3 ambient = SampleSH(IN.normal);//이부분 정확히 무엇을 하는지 이해 안감

                half3 lighting = NdotL * lightInfo.color * lightInfo.shadowAttenuation * lightInfo.distanceAttenuation + ambient;

                color.rgb *=lighting;

                color *=_BaseColor;

                color.rgb +=spec * lightInfo.shadowAttenuation * half3(1,1,1);

                return color;
                
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}