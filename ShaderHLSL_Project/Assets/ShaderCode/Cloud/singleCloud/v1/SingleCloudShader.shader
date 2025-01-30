Shader "ShaderCode/Cloud/SingleCloudShader"
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
        _CloudTex("Cloud Texture",3D) = "white"{}
        _CloutTexOffset("Cloud Texture Offset",vector) = (0,0,0,0)

        [Space(15)]
        _LightStepNum("Light Steps",int) = 16
        _LightStepSize("Light Step Size",float) = 0.1
        _LightAbssorb("Light Abssorbness",float) = 2
        _Transmittance("Light Transmittance",float) = 0.5
        _ShadowThreshHold("Shadow ThreshHold",float) = 0.2
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


            TEXTURE3D(_CloudTex);
            SAMPLER(sampler_CloudTex);

            CBUFFER_START(Unity_PerMaterial)
                int _MAX_MARCHING_STEPS;
                float _MAX_MARCHING_DISTANCE;
                float _SURFACE_DISTANCE;

                int _CLOUD_MARCHING_STEPS;
                float _CLOUD_STEP_SIZE;

                float4 _MainCol;
                float4 _ShadowCol;
                float _DensityScale;
                float4 _CloutTexOffset;

                int _LightStepNum;
                float _LightStepSize;
                float _LightAbssorb;
                float _Transmittance;
                float _ShadowThreshHold;
                float _HenyeyGreensteinG;
            CBUFFER_END

            //Ray Marchind�� ����� ��ũ�� ������
            //#define MAX_MARCHING_STEPS 60
            //#define MAX_MARCHING_DISTANCE 10
            //#define SURFACE_DISTANCE 0.001

            //������ �� SDF
            float SphereSDF(float3 pos, float3 spherePosOS, float radius){
                float3 spherePosWS = spherePosOS;//���� ��ġ�� ���� �����̽��� ��ȯ
                return length(pos - spherePosWS) - radius;
            }

            //Ray Marching�� ����Ͽ� ������ ������ġ���� ������ �̵�(����ȭ)
            float RayMarching(float3 ray_origin, float3 ray_dir)
            {
                float dis = 0;

                for(int i = 0; i< _MAX_MARCHING_STEPS;i++){
                    //Ray ��ġ ���
                    float3 ray_pos = ray_origin + ray_dir * dis;

                    //�������� �Ÿ� ���
                    float calDis = SphereSDF(ray_pos,float3(0,0,0),0.6);

                    //�������� �Ÿ��� Ray �Ÿ��� ����
                    dis += calDis;

                    //Ray�� ���� �ε����� ��� �Ǵ� �ʹ� �ָ� �� ��� ������
                    if(calDis < _SURFACE_DISTANCE || dis > _MAX_MARCHING_DISTANCE) break;
                }

                return dis;
            }

            //��Ȯ�� ����Ʈ ������ ���� �Լ�(Anisotropic Scattering)
            float HenyeyGreenstein(float g, float costh)
            {
                return (1.0/ (4.0 * 3.14)) * ((1.0 - g*g) / pow(1.0 + g*g - 2.0*g*costh,1.5));
            }

            //Cloud ������ ����
            float3 CloudMarching(float3 rayOrigin, float3 ray_dir, float3 lightDir)
            {
                float _density = 0;

                float transmission = 0;
                float lightAccumulation = 0;
                float finalLight = 0;
                //float4 res = float4(0,0,0,0);

                //Cloud density�� ������ ���
                for(int i = 0;i <60;i++)
                {
                    rayOrigin += (ray_dir * _CLOUD_STEP_SIZE);

                    //�������� �Ÿ� ���
                    float calDis = SphereSDF(rayOrigin,float3(0,0,0),0.6);

                    
                    if(calDis < 0){
                        float sampleDensity = SAMPLE_TEXTURE3D(_CloudTex,sampler_CloudTex,rayOrigin + _CloutTexOffset.xyz).r;
                        //_density += sampleDensity * _CLOUD_STEP_SIZE * _DensityScale;
                        _density += sampleDensity * _DensityScale;
                        
                    }
                    else break;

                    float costh = dot(ray_dir,lightDir);
                    float scatter = HenyeyGreenstein(_HenyeyGreensteinG,costh);

                    float3 lightRayOrigin = rayOrigin + _CloutTexOffset.xyz;
                    for(int j=0; j<30; j++){
                        //calDis = SphereSDF(rayOrigin,float3(0,0,0),0.6);
                        //if(calDis > 0) break;
                        
                        lightRayOrigin += lightDir * _LightStepSize;
                        float lightDensity = SAMPLE_TEXTURE3D(_CloudTex,sampler_CloudTex,lightRayOrigin).r;

                        lightAccumulation +=lightDensity * scatter;
                    }

                    float lightTransmission = exp(-lightAccumulation);
                    float shadow = _ShadowThreshHold + lightTransmission * (1 - _ShadowThreshHold);

                    finalLight += _density * _Transmittance * shadow;

                    _Transmittance *=exp(-_density * _LightAbssorb);
                }

                transmission = exp(-_density);

                return float3(finalLight,transmission,_Transmittance);
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

                //Ray �� �������� ���� ���(Object Space���� ���)
                float3 ray_origin = TransformWorldToObject(_WorldSpaceCameraPos);
                //float3 ray_origin = float3(10,10,0);
                float3 ray_dir = normalize(IN.positionOS - ray_origin);

                //Ray ���� ���� ���ϱ�
                float dis = RayMarching(ray_origin,ray_dir);
                float3 ray_finalPos = ray_origin + ray_dir * dis;

                Light mainLight = GetMainLight();
                //return float4(TransformWorldToObjectDir(mainLight.direction),1);

                //Cloud Rendering ����
                //float _density = CloudMarching(ray_finalPos,ray_dir,mainLight.direction);
                float3 res = CloudMarching(ray_finalPos,ray_dir,TransformWorldToObjectDir(mainLight.direction));

                half4 finalCol = lerp(_ShadowCol,_MainCol,res.r);
                finalCol.a = 1 - res.g;//alpha = 1 - density
                //finalCol.a = _density * _DensityScale;

                return finalCol;
            }
            ENDHLSL
        }

    }
}