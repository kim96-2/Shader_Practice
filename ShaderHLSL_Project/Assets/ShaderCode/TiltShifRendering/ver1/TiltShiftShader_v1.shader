//Tilt Shift Shader ver1
//Blur 량을 화면 비율 내 특정 범위만 적용함
Shader "ShaderCode/TiltShift_v1"
{

    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}

        [Space(15)]
        _MaxGridSize ("Max Grid Size", Integer) = 3

        [Space(15)]
        _TiltCenter("Tilt Center", Range(0,1)) = 0.5
        _TiltNotBlurRange("Tilt Not Blur Range", Range(0,1)) = 0.1 
        _TiltLerpRange("Tilt Lerp Range", Range(0,1)) = 0.2

        [Space(15)]
        _Spread ("Blur Spread" , float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
        
        HLSLINCLUDE//HLSLPROGRAM 이 아닌 HLSLINCLUDE로 정의

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
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

        //ver1 : 
        float CalculateTiltBlurAmount(float y)
        {
            float amount = abs(y - _TiltCenter);
            amount = lerp(0, 1, (amount - _TiltNotBlurRange) / (_TiltLerpRange + 0.001));

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

                int grid = lerp(0, _MaxGridSize, CalculateTiltBlurAmount(IN.uv.y));

                [loop]
                for(int x = -grid; x <= grid; x++)
                {
                    float gauss = gaussian(x);

                    gridSum += gauss;
                    
                    float2 uv = IN.uv + float2(1.0 , 0.0) * _MainTex_TexelSize.x * (float)x;
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

                int grid = lerp(0, _MaxGridSize, CalculateTiltBlurAmount(IN.uv.y));

                [loop]
                for(int y = -grid; y <= grid; y++)
                {
                    float gauss = gaussian(y);

                    gridSum += gauss;
                    
                    float2 uv = IN.uv + float2(0.0 , 1.0) * _MainTex_TexelSize.y * (float)y;
                    col += gauss * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
                }

                col /= gridSum;

                return half4(col, 1.0);
            }
            ENDHLSL
        }
    }
}
