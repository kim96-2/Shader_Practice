Shader "ShaderCode/Gouraud Shader"
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
                float3 NdotL : TEXCOORD1;
                float3 NdotH : TEXCOORD2;
                float3 ambient : TEXCOORD3;
                float fogCoord : TEXCOORD4;
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
                //OUT.normal = TransformObjectToWorldNormal(IN.normal);

                //fog ���� frag���� ����ϰ� ����
                OUT.fogCoord = ComputeFogFactor(OUT.positionHCS.z);

                //vert���� NdotL, NdotH�� ����ϰ� frag���� �� ������ ������ �� ���
                float4 shadowCoord = GetShadowCoord(vertexInput);
                Light lightInfo = GetMainLight(shadowCoord);

                float3 normal = TransformObjectToWorldNormal(IN.normal);

                //NdotL ���. NdotL�� light �׸��ڿ� �÷����� ���� ���ؼ� ����
                OUT.NdotL = saturate(dot(normal,lightInfo.direction))
                            * lightInfo.shadowAttenuation * lightInfo.distanceAttenuation * lightInfo.color;

                float3 viewDir = normalize(_WorldSpaceCameraPos - vertexInput.positionWS);
                
                //�ݻ籤 ���(BlinnPhong)
                float3 h = normalize(lightInfo.direction + viewDir);
                float spec = pow(saturate(dot(h,normal)),_SpecPower);
                OUT.NdotH = spec
                            * lightInfo.shadowAttenuation * lightInfo.distanceAttenuation; 

                OUT.ambient = SampleSH(normal);//ambient�� vert���� ���

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {        
                half4 color = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,IN.uv);

                //half3 ambient = SampleSH(IN.normal);//�̺κ� ��Ȯ�� ������ �ϴ��� ���� �Ȱ�

                half3 lighting = IN.NdotL + IN.ambient;

                color.rgb *=lighting;

                color *=_BaseColor;

                color.rgb +=IN.NdotH;

                color.rgb = MixFog(color.rgb,IN.fogCoord);

                //color.rgb = (lightInfo.shadowAttenuation*0.5 + 0.5) * NdotL * float3(1,1,1);

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