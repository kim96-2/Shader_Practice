//Tilt Shift Shader ver2
//Blur 량을 뎁스를 고려하여 적용
Shader "ShaderCode/TiltShift_v2"
{

    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}

        [Space(15)]
        _MaxGridSize ("Max Grid Size", Integer) = 3

        [Space(15)]
        _TiltCenter("Tilt Center", Float) = 30
        _TiltNotBlurRange("Tilt Not Blur Range", Float) = 5 
        _TiltLerpRange("Tilt Lerp Range", Float) = 10

        [Space(15)]
        _Spread ("Blur Spread" , float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
        
        HLSLINCLUDE//HLSLPROGRAM 이 아닌 HLSLINCLUDE로 정의

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        #define E 2.71828

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_TexelSize;

        float _Spread;

        int _MaxGridSize;

        float _TiltCenter;
        float _TiltNotBlurRange;
        float _TiltLerpRange;
                
        CBUFFER_END

        float gaussian(int x)
        {
            float sigmaSqu = _Spread * _Spread;

            return (1 / sqrt(TWO_PI * sigmaSqu)) * pow(E, - (x * x) / (2 * sigmaSqu));
        }

        //ver2 : 
        float CalculateTiltBlurAmount(float2 positionSS)
        {
            float rawDepth = SampleSceneDepth(positionSS);
            float linearDepth = LinearEyeDepth(rawDepth, _ZBufferParams);

            float amount = abs(linearDepth - _TiltCenter);
            amount = (amount - _TiltNotBlurRange) / (_TiltLerpRange + 0.001);

            return saturate(amount);
        }

        struct Attributes
        {
            float4 positionOS   : POSITION;       
            float2 uv           : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionHCS  : SV_POSITION;
            float2 uv           : TEXCOORD0;
        };            


        Varyings vert(Attributes IN)
        {

            Varyings OUT;

            OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
            OUT.uv = IN.uv;

            return OUT;
        }

        ENDHLSL

        Pass//0번 가로 Blur Pass
        {
            Name "Horizontal"

            HLSLPROGRAM
 
            #pragma vertex vert
            #pragma fragment frag

         
            half4 frag(Varyings IN) : SV_Target
            {
                float3 col = float3(0, 0, 0);
                float gridSum = 0;

                int grid = lerp(0, _MaxGridSize, CalculateTiltBlurAmount(IN.uv));

                //Blur가 안들어가는 부분은 아래 계산 안하기
                if(grid == 0)
                {
                    col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb;
                    return half4(col, 1.0); 
                }

                [loop]
                for(int x = -grid; x <= grid; x++)
                {
                    float gauss = gaussian(x);
     
                    float2 uv = IN.uv + float2(1.0 , 0.0) * _MainTex_TexelSize.x * (float)x;

                    //Tilt Blur 량을 고려해서 블러 넣어줌
                    gauss *= CalculateTiltBlurAmount(uv);
                    gridSum += gauss;

                    col += gauss * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
                }

                col /= gridSum;

                return half4(col, 1.0);
            }
            ENDHLSL
        }

        Pass//1번 세로 Blur Pass
        {
            Name "Vertical"

            HLSLPROGRAM
 
            #pragma vertex vert
            #pragma fragment frag

         
            half4 frag(Varyings IN) : SV_Target
            {
                float3 col = float3(0, 0, 0);
                float gridSum = 0;

                int grid = lerp(0, _MaxGridSize, CalculateTiltBlurAmount(IN.uv));

                //Blur가 안들어가는 부분은 아래 계산 안하기
                if(grid == 0)
                {
                    col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb;
                    return half4(col, 1.0); 
                }

                [loop]
                for(int y = -grid; y <= grid; y++)
                {
                    float gauss = gaussian(y);
                    
                    float2 uv = IN.uv + float2(0.0 , 1.0) * _MainTex_TexelSize.y * (float)y;

                    //Tilt Blur 량을 고려해서 블러 넣어줌
                    gauss *= CalculateTiltBlurAmount(uv);
                    gridSum += gauss;

                    col += gauss * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
                }

                col /= gridSum;

                return half4(col, 1.0);
            }
            ENDHLSL
        }
    }
}
