//아래 사이트를 참조하여 제작하였는데... 결과가 좋지 않다....
//https://blog.maximeheckel.com/posts/real-time-cloudscapes-with-volumetric-raymarching/
Shader "ShaderCode/Cloud/SingleCloudShaderv2"
{
    Properties
    {
        [Header(Ray March Setting)]
        _MAX_MARCHING_STEPS("Ray Marching Steps",int) = 60
        _MAX_MARCHING_DISTANCE("Max Ray Marhcing Distance",float) = 10
        _SURFACE_DISTANCE("Min Ray marching Distance",float) = 0.001

        [Header(Cloud March Setting)]
        _CLOUD_MARCHING_STEPS("Cloud Marching Steps",int) = 60
        _CLOUD_STEP_SIZE("Cloud Marching Step Size", float) = 0.01


        [Header(Cloud Setting)]
        _MainCol("Cloud Color",color) = (1,1,1,1)
        _ShadowCol("Cloud Shadow Color",color) = (0,0,0,1)
        _DensityScale("Density Scale",float) = 0.5

        [Space(15)]
        _HenyeyGreensteinG("HenyeyGreenstein G",Range(0,1)) = 0.9
    }

    SubShader
    {
        

        Tags { 
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline" 
        }
        
        Pass
        {
            //Tags {"LightMode" = "UniversalForward"}
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            Cull Front


            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            //#pragma exclude_renderers d3d11_9x
            //#pragma exclude_renderers d3d9

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"           
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            

            struct Attributes
            {
                
                float4 positionOS   : POSITION;     
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {

                float4 positionHCS  : SV_POSITION;
                float3 positionOS   : TEXCOORD0;

            };            


            CBUFFER_START(Unity_PerMaterial)
                int _MAX_MARCHING_STEPS;
                float _MAX_MARCHING_DISTANCE;
                float _SURFACE_DISTANCE;

                int _CLOUD_MARCHING_STEPS;
                float _CLOUD_STEP_SIZE;

                float4 _MainCol;
                float4 _ShadowCol;
                float _DensityScale;

                float _HenyeyGreensteinG;
            CBUFFER_END

            

            //아래 사이트에서 참조한 fbm 함수(렌덤 함수)
            //https://www.shadertoy.com/view/WdXGRj

            float hash(float n )
            {
                return frac(sin(n * 6)*758.5453);
            }

            float noise(float3 x )
            {
                float3 p = floor(x);
                float3 f = frac(x);

                f = f*f*(4.0-3.0*f);

                float n = p.x + p.y*57.0 + 113.0*p.z;

                float res = lerp(lerp(lerp( hash(n+  0.0), hash(n+  1.0),f.x),
                                    lerp( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y),
                                lerp(lerp( hash(n+113.0), hash(n+114.0),f.x),
                                    lerp( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
                return res;
            }

            float fbm(float3 p )
            {
                float3x3 m = float3x3( 0.00,  0.80,  0.60,
                -0.80,  0.36, -0.48,
                -0.60, -0.48,  0.64 );

                float f;
                f  = 0.5000*noise( p ); p = mul(m,p)*2.02;
                f += 0.2500*noise( p ); p = mul(m,p)*2.03;
                f += 0.12500*noise( p ); p = mul(m,p)*2.01;
                f += 0.06250*noise( p );
                return f;
            }

            //간단한 구 SDF
            float SphereSDF(float3 pos, float3 spherePosOS, float radius){
                return length(pos - spherePosOS) - radius;
            }

            //정확한 라이트 분포를 위한 함수(Anisotropic Scattering)
            float HenyeyGreenstein(float g, float costh)
            {
                return (1.0/ (4.0 * 3.14)) * ((1.0 - g*g) / pow(1.0 + g*g - 2.0*g*costh,1.5));
            }

            float Scene(float3 pos)
            {
                float dis = SphereSDF(pos,float3(0,0,0),0.3);

                float _fbm = fbm(pos + float3(1,0,0) * _Time.y * 0.5);
                //_fbm = hash(pos.x + 0.5) - hash(pos.y) - hash(pos.z);

                return -dis + _fbm * 0.3;
            }

            //Cloud 렌더링 시작
            float4 CloudMarching(float3 rayOrigin, float3 rayDir, float3 lightDir)
            {
                float depth = 0;
                float3 pos = rayOrigin + depth * rayDir;

                lightDir = normalize(lightDir);

                float4 res = float4(0,0,0,0);

                

                for(int step = 0; step < _CLOUD_MARCHING_STEPS;step++)
                {
                    float _density = Scene(pos);

                    depth += _CLOUD_STEP_SIZE;
                    pos = rayOrigin + depth * rayDir;

                    
                    if(_density > 0)
                    {
                        //새로운 라이팅 계산 방식
                        float _diffuse = saturate(Scene(pos) - Scene(pos + 0.2 * lightDir)) / 0.2;

                        float3 lin = _diffuse * 5;
                        
                        float4 col = float4(lerp(float3(0,0,0),float3(1,1,1),exp(-_density)), _density);
                        col.rgb *= lin;
                        col.rgb *= col.a;

                        res +=col * (1 - res.a);
                    }
                    
                    
                }

                res.rgb = lerp(_ShadowCol.rgb,_MainCol.rgb,res.r);

                return res;
            }

            Varyings vert(Attributes IN)
            {

                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionOS = IN.positionOS.xyz;

                return OUT;
            }

          
            half4 frag(Varyings IN) : SV_Target
            {

                //Ray 의 시작점과 방향 계산(Object Space에서 계산)
                float3 ray_origin = TransformWorldToObject(_WorldSpaceCameraPos);
                float3 ray_dir = normalize(IN.positionOS - ray_origin);

                Light mainLight = GetMainLight();

                //Cloud Rendering 진행
                //float _density = CloudMarching(ray_finalPos,ray_dir,mainLight.direction);
                float4 res = CloudMarching(ray_origin,ray_dir,TransformWorldToObjectDir(mainLight.direction));

                return float4(res.rgb,saturate(res.a * 10));

                //return finalCol;
            }
            ENDHLSL
        }

    }
}