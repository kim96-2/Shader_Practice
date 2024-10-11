Shader "ShaderCode/Skin Shader"
{    
    // The _BaseColor variable is visible in the Material's Inspector, as a field 
    // called Base Color. You can use it to select a custom color. This variable
    // has the default value (1, 1, 1, 1).
    Properties
    { 
        _MainTex("Main Texture",2D) = "white"{}
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)

        [Space(10)]
        [Header(Specular Setting)]
        _SpecPower("Specular Power",float) = 10

        [Space(10)]
        [Header(SSS Setting)]
        _ThicknessTex("Thickness Map",2D) = "black"{}
        _SssColor("SSS Color",color) = (0,0,0,0)
        _Attenuation("Attenuation",Range(0,5)) = 1
        _Distortion("Distortion",Range(0,1)) = 1
        _SssPower("SSS Power",Range(0.001,5)) = 1
        _SssScale("SSS Scale",Range(0,5)) = 1


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

            #pragma multi_compile_fog

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
                float3 viewDir : TEXCOORD2;
                //float4 shadowCoord : TEXCOORD3;
                float fogCoord : TEXCOORD3;

                VertexPositionInputs vertexInput: TEXCOORD4;
            };

            // To make the Unity shader SRP Batcher compatible, declare all
            // properties related to a Material in a a single CBUFFER block with 
            // the name UnityPerMaterial.

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            
            TEXTURE2D(_ThicknessTex);
            SAMPLER(sampler_ThicknessTex);

            CBUFFER_START(UnityPerMaterial)
                // The following line declares the _BaseColor variable, so that you
                // can use it in the fragment shader.
                float4 _MainTex_ST;

                half4 _BaseColor;       
                float _SpecPower;     

                float4 _ThicknessTex_ST;

                float4 _SssColor;
                float _Attenuation;
                float _Distortion;
                float _SssScale;
                float _SssPower;

            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                
                //OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionHCS = OUT.vertexInput.positionCS;
                OUT.uv = TRANSFORM_TEX(IN.uv , _MainTex);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);

                OUT.viewDir = normalize(_WorldSpaceCameraPos - OUT.vertexInput.positionWS);

                //OUT.shadowCoord = GetShadowCoord(vertexInput);

                OUT.fogCoord = ComputeFogFactor(OUT.positionHCS.z);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                IN.normal = normalize(IN.normal);
                IN.viewDir = normalize(IN.viewDir);

                Light lightInfo = GetMainLight(GetShadowCoord(IN.vertexInput));

                half4 color = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,IN.uv);

                float NdotL = dot(IN.normal,lightInfo.direction);
                NdotL = saturate(NdotL);

                //�ݻ籤 ���(BlinnPhong)
                float3 h = normalize(lightInfo.direction + IN.viewDir);
                half spec = saturate(dot(h,IN.normal));

                spec = pow(spec,_SpecPower);

                half3 ambient = SampleSH(IN.normal);//�̺κ� ��Ȯ�� ������ �ϴ��� ���� �Ȱ�
                
                //SSS ����� ���� Thickness Map �ؽ��� ���ø�
                float thickness = SAMPLE_TEXTURE2D(_ThicknessTex,sampler_ThicknessTex,IN.uv);

                //SSS ���(���� : https://blog.naver.com/mnpshino/221442196618)
                float3 h_SSS = normalize(lightInfo.direction + IN.normal * _Distortion);
                float VdotH_SSS = pow(saturate(dot(IN.viewDir,-h_SSS)),_SssPower) * _SssScale;
                float3 backLight = _Attenuation * VdotH_SSS * thickness * _SssColor.rgb;

                //diffuse light ���
                half3 lighting = NdotL * lightInfo.shadowAttenuation * lightInfo.distanceAttenuation;

                //Ambient�� diffuse�� ����
                lighting = lerp(ambient,1,lighting);

                color.rgb *=lighting * lightInfo.color;

                //Ambient �����ֱ�
                //color.rgb += ambient * 0.5;

                //Base Color ����
                color *=_BaseColor;

                //Specular ��� �� ����
                color.rgb +=spec * lightInfo.shadowAttenuation;

                //SSS �����ֱ�
                color.rgb += backLight * lightInfo.color;

                color.rgb = MixFog(color.rgb,IN.fogCoord);

                return color;
                
            }
            ENDHLSL
        }
        //UsePass "Universal Render Pipeline/Lit/ShadowCaster"�ٸ� ���̴��� �н��� ������ �� ����
        Pass//�Ǵ� �̷��� ���ο� �н��� ����� �̹� ������� hlsl ���̴��� ������ �� �ִ�
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Front

            HLSLPROGRAM

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            //���� �ִ� hlsl�� ������ �� ������ �ѹ� Ȯ���� ����

            ENDHLSL
        }

        Pass//Depth �׸��� Pass
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