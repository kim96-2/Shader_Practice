Shader "ShaderCode/ShaderUsing"
{    
    // The _BaseColor variable is visible in the Material's Inspector, as a field 
    // called Base Color. You can use it to select a custom color. This variable
    // has the default value (1, 1, 1, 1).
    Properties
    { 
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)

        _DepthMaxDis("Depth Max Distence",float) = 5.0
        _DepthShallowColor("Depth Shallow Color",Color) = (1, 1, 1, 1)
        _DepthDeepColor("Depth Deep Color",Color) = (0, 0, 0, 1)

        _NoiseColor("Noise Color",Color) = (1, 1, 1, 1)

        _NoiseTex("Noise Texture",2D) = "black"{}
        _NoiseCutoff("Noise CutOff",Range(0,1)) = 0.5
        _NoiseSize("Noise Size",float) = 100

        _DistortionTex("Distortion Texture",2D) = "white"{}
        _DistortionAmount("Distortion Amount",Range(0, 1)) = 0.1

        [ShowAsVector2] _NoiseScrollSpeed("Noise Scroll Speed",vector) = (0.01, 0.01, 0, 0)

        _SurfaceCutoff("Surface CutOff",Range(0,1)) = 0.5
    }
    
    SubShader
    {   //���� �ؽ��İ� ����ũ ť ���Ŀ� �׷����Ƿ� Ʈ�����䷱Ʈ ť�� �־���     
        Tags 
        {
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"         
        }
                
        Pass
        {            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //���� ���� ����� ���� ��Ŭ���
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
            struct Attributes
            {
                float4 positionOS   : POSITION;       
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionVS : TEXCOORD0;//�� ��ǥ�� ����
                float4 screenPos : TEXCOORD1;//ȭ�� ��ǥ�� ����

                float3 viewDir : TEXCOORD2;

                float2 noiseUV : TEXCOORD3;
            };

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            TEXTURE2D(_DistortionTex);
            SAMPLER(sampler_DistortionTex);

            // To make the Unity shader SRP Batcher compatible, declare all
            // properties related to a Material in a a single CBUFFER block with 
            // the name UnityPerMaterial.
            CBUFFER_START(UnityPerMaterial)
                float4 _NoiseTex_ST;
                float4 _DistortionTex_ST;

                // The following line declares the _BaseColor variable, so that you
                // can use it in the fragment shader.
                half4 _BaseColor;     
                
                float _NoiseSize;
                
                float _DepthMaxDis;
                float4 _DepthShallowColor;
                float4 _DepthDeepColor;

                float4 _NoiseColor;

                float _NoiseCutoff;

                float4 _NoiseScrollSpeed;

                float _DistortionAmount;

                float _SurfaceCutoff;
            CBUFFER_END

            //���� ����Ƽ �׷����Ʈ ������ �Լ� ������
            float2 unity_gradientNoise_dir(float2 p)
            {
                p = p % 289;
                float x = (34 * p.x + 1) * p.x % 289 + p.y;
                x = (34 * x + 1) * x % 289;
                x = frac(x / 41) * 2 - 1;
                return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
            }

            float unity_gradientNoise(float2 p)
            {
                float2 ip = floor(p);
                float2 fp = frac(p);
                float d00 = dot(unity_gradientNoise_dir(ip), fp);
                float d01 = dot(unity_gradientNoise_dir(ip + float2(0, 1)), fp - float2(0, 1));
                float d10 = dot(unity_gradientNoise_dir(ip + float2(1, 0)), fp - float2(1, 0));
                float d11 = dot(unity_gradientNoise_dir(ip + float2(1, 1)), fp - float2(1, 1));
                fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
                return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x);
            }

            void Unity_GradientNoise_float(float2 UV, float Scale, out float Out)
            {
                Out = unity_gradientNoise(UV * Scale) + 0.5;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);

                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.positionVS = TransformWorldToView(positionWS);

                OUT.screenPos =  ComputeScreenPos(OUT.positionHCS);//Ŭ�� ��ǥ�踦 ȭ�� ��ǥ��� ����

                OUT.viewDir = _WorldSpaceCameraPos - positionWS;

                OUT.noiseUV = TRANSFORM_TEX(IN.uv, _NoiseTex);
                //OUT.noiseUV = float4(OUT.noiseUV.x,OUT.noiseUV.y * _NoiseTex_TexelSize.x)

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //���� ��ġ�� Depth Texture �� ���
                float rawDepth = SampleSceneDepth(IN.screenPos.xy / IN.screenPos.w);
                float sceneEyeDepth = LinearEyeDepth(rawDepth,_ZBufferParams);
                
                //���� ��ġ�� ������Ʈ Depth �� ���
                float fragmentEyeDepth = -IN.positionVS.z;

                float depthDiffernce = sceneEyeDepth - fragmentEyeDepth;

                //������ �ִ�ġ�� �ణ�� �������� �������
                float depthDis = saturate(depthDiffernce / _DepthMaxDis);
                depthDis = pow(depthDis,0.3);

                
                float4 depthCol = lerp(_DepthShallowColor,_DepthDeepColor,depthDis);

                //Depth Texture�� ������ World Position�� ����ȯ(�� ���) �ϴ� ���
                //float3 worldPos = _WorldSpaceCameraPos - ( (IN.viewDir / fragmentEyeDepth) * sceneEyeDepth);

                float2 distortionSample = (SAMPLE_TEXTURE2D(_DistortionTex,sampler_DistortionTex,IN.noiseUV).xy * 2 - 1) * _DistortionAmount;

                //������ uv ���
                float2 finalNoiseUV = float2(IN.noiseUV.x + _Time.y * _NoiseScrollSpeed.x + distortionSample.x, IN.noiseUV.y + _Time.y * _NoiseScrollSpeed.x + distortionSample.y);

                //���� �� �� �Ͼ�� ����� ǥ���ϱ� ���� ����
                float edge = SAMPLE_TEXTURE2D(_NoiseTex,sampler_NoiseTex,finalNoiseUV).r;
                
                Unity_GradientNoise_float(finalNoiseUV,_NoiseSize, edge);//�ؽ��İ� ȭ���� �ʹ� ���� ����Ƽ �׷����Ʈ ������ �Լ��� ���� ����غ�
                edge = pow(edge,2);
                //edge += depthDis * _SurfaceCutoff;

                float depthCutOff =1 - saturate((depthDiffernce) / (_SurfaceCutoff));

                edge = edge + depthCutOff + sin(_Time.y) * 0.05 ;
                edge = edge>_NoiseCutoff  ? 1 : 0;

                half4 col = lerp(depthCol,_NoiseColor,edge);//���� �κп� ������ �÷��� ����

                

                //return _BaseColor * float4(frac(worldPos), 1.0);
                return _BaseColor * col;
            }
            ENDHLSL
        }
    }
}