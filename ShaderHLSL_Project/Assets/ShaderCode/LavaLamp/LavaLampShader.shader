//Ray Marching�� ����� �������� ����
Shader "ShaderCode/LavaLamp"
{
    Properties
    {
        _Smoothness("SDF Smoothness",float) = 0.5

        _Strength("Ramp Strength", float) = 2

        [Space(10)]
        [HDR]_Color1("Ramp Color 1",Color) = (1,1,1,1)
        [HDR]_Color2("Ramp Color 2",Color) = (1,1,1,1)
    }

    SubShader
    {
        

        Tags { 
            "RenderType" = "Opaque"
            "Queue" = "AlphaTest"//alpha clip�� ����ϱ� ������ alpha clip�� �־���
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
                float3 positionWS   : TEXCOORD0;

            };            


            CBUFFER_START(Unity_PerMaterial)
                float _Smoothness;

                float _Strength;

                float4 _Color1;
                float4 _Color2;
            CBUFFER_END

            //Ray Marchind�� ����� ��ũ�� ������
            #define MAX_MARCHING_STEPS 60
            #define MAX_DISTANCE 10
            #define SURFACE_DISTANCE 0.001

            //Boolen Operators
            float Union(float a,float b){
                return min(a,b);
            }

            float SmoothUnion(float a, float b, float k){
                float h = clamp(0.5 + 0.5*(b - a)/ k, 0.0 , 1.0);
                return lerp(b, a , h) - k * h * (1 - h);
            }

            float intersection(float a, float b){
                return max(a,b);
            }

            float SmoothIntersection(float a, float b, float k){
                float h = clamp( 0.5 - 0.5*(b-a)/k, 0.0, 1.0 );
                return lerp( b, a, h ) + k*h*(1.0-h);
            }

            //������ ��� SDF
            float planeSDF(float3 pos, float edge){
                float plane = pos.y - edge;
                return plane;
            }

            //������ �� SDF
            float SphereSDF(float3 pos, float3 spherePosOS, float radius){
                float3 spherePosWS = TransformObjectToWorld(spherePosOS);//���� ��ġ�� ���� �����̽��� ��ȯ
                return length(pos - spherePosWS) - radius;
            }

            //����ϰ� ���� �ձ� �Ǹ��� SDF(��� ���� �־ ���ذ� �Ȱ���)
            float RoundCylinderSDF(float3 pos, float3 sdfPos, float ra, float rb, float h){
                pos = pos - TransformObjectToWorld(sdfPos);
                float2 d = float2(length(pos.xz) - 2.0*ra + rb,abs(pos.y) - h);
                return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
            }

            //SDF�� �ּ� �Ÿ� ��� �Լ�
            float GetDistance(float3 pos){
                //xyz���� ��ġ��, w���� ũ�Ⱚ ����
                float4 sphere1 = float4(0.45 * sin(_Time.y * 0.3),sin(_Time.y * 0.2),0.45 * sin(_Time.y * -0.65),0.24);
                float4 sphere2 = float4(0.45 * sin(_Time.y * -0.2),cos(_Time.y * -0.52),0.45 * sin(_Time.y * 0.12),0.38);
                float4 sphere3 = float4(0.45 * sin(_Time.y * 0.7),sin(_Time.y * -0.13),0.45 * sin(_Time.y * 0.32),0.32);
                float4 sphere4 = float4(0,-1,0,0.5);

                float sp1 = SphereSDF(pos,sphere1.xyz , sphere1.w);
                float sp2 = SphereSDF(pos,sphere2.xyz , sphere2.w);
                float sp3 = SphereSDF(pos,sphere3.xyz , sphere3.w);
                float sp4 = SphereSDF(pos,sphere4.xyz , sphere4.w);

                float cylinder = RoundCylinderSDF(pos,float3(0,0,0),0.3,0.1,0.9);

                float dis = SmoothUnion(sp1,sp2, _Smoothness);
                dis = SmoothUnion(dis, sp3, _Smoothness);
                dis = SmoothUnion(dis, sp4, _Smoothness);

                dis = SmoothIntersection(dis,cylinder,0.1);

                //return cylinder;
                return dis;
            }

            //SDF�� �̷���� ������Ʈ���� �븻�� ��� �Լ�
            float3 GetNormal(float3 pos){
                float dis = GetDistance(pos);
                float2 e = float2(0.01,0.0);
                float3 normal = float3(
                    dis - GetDistance(pos - e.xyy),
                    dis - GetDistance(pos - e.yxy),
                    dis - GetDistance(pos - e.yyx)
                );

                return normalize(normal);
            }

            float RayMarching(float3 ray_origin,float3 ray_dir){
                float dis = 0;

                for(int i = 0; i< MAX_MARCHING_STEPS;i++){
                    //Ray ��ġ ���
                    float3 ray_pos = ray_origin + ray_dir * dis;

                    //�������� �Ÿ� ���
                    float calDis = GetDistance(ray_pos);

                    //�������� �Ÿ��� Ray �Ÿ��� ����
                    dis += calDis;

                    //Ray�� ���� �ε����� ��� �Ǵ� �ʹ� �ָ� �� ��� ������
                    if(calDis < SURFACE_DISTANCE || dis > MAX_DISTANCE) break;
                }

                return dis;
            }

            Varyings vert(Attributes IN)
            {

                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);

                return OUT;
            }

          
            half4 frag(Varyings IN) : SV_Target
            {

                //Ray �� �������� ���� ���(Object Space���� ���)
                float3 ray_origin = _WorldSpaceCameraPos;
                //float3 ray_origin = float3(10,10,0);
                float3 ray_dir = normalize(IN.positionWS - ray_origin);

                //Ray ���� ���� ���ϱ�
                float dis = RayMarching(ray_origin,ray_dir);
                float3 ray_finalPos = ray_origin + ray_dir * dis;

                if(dis > MAX_DISTANCE) discard;

                float3 normal = GetNormal(ray_finalPos);

                float NdotV = saturate(dot(normal,-ray_dir));
                NdotV = pow(NdotV,max(_Strength,0.01));


                return lerp(_Color1,_Color2,NdotV);
            }
            ENDHLSL
        }

    }
}