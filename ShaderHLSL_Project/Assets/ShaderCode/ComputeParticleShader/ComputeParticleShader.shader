Shader "ShaderCode/ComputeParticle"
{
    Properties
    {
        _PointSize("Point size", Float) = 5.0
    }

    SubShader
    {
        
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            //#pragma target 4.5

            struct Particle{
                float3 position;
                float3 velocity;
                float life;
            };

            StructuredBuffer<Particle> _ParticleBuffer;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)

            float _PointSize;

            CBUFFER_END


            struct Attributes
            {
                float4 positionOS   : POSITION;
                uint instanceID : SV_InstanceID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float4 color : COLOR;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                //#if SHADER_TARGET >= 45
                    Particle particle = _ParticleBuffer[IN.instanceID];
                //#else
                    //Particle particle = (Particle)0;
                //#endif

                // Color
			    float lerpVal = particle.life * 0.25f;
			    OUT.color = half4(1.0f - lerpVal+0.1, lerpVal+0.1, 1.0f, lerpVal);

			    // Position
                //OUT.positionHCS = TransformObjectToHClip(particle.position);
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS * _PointSize + particle.position);

                //OUT.size = _PointSize;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return IN.color;
                //return 1;
            }
            ENDHLSL
        }
    }
}