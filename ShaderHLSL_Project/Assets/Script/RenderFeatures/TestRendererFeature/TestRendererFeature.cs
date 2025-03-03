using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;
using UnityEngine.Rendering.Universal;

namespace TestRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        [Header("Draw Renderers Settings")]
        public bool useRendererSetting = true;
        public LayerMask layerMask = 1;
        public Material overrideMaterial;
        public int overrideMaterialPass;

        [Header("Blit Settings")]
        public Material blitMaterial;
    }

    /// <summary>
    /// 아래 링크 보고 만들어본 테스트 Renderer feature
    /// https://www.cyanilux.com/tutorials/custom-renderer-features/
    /// </summary>
    public class TestRendererFeature : ScriptableRendererFeature
    {

        public Settings settings;
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;

        TestRenderPass testRenderPass;

        public override void Create()
        {
            testRenderPass = new TestRenderPass(settings,"Test Render Pass");

            // Configures where the render pass should be injected
            testRenderPass.renderPassEvent = renderPassEvent;
        }

        // Here you can inject one or multiple render passes in the renderer.
        // This method is called when setting up the renderer once per-camera (every frame!)
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            //프리뷰 카메라에서는 적용 안되게 
            if (renderingData.cameraData.isPreviewCamera) return;

            //씬 뷰 카메라 에서도 적용 안되게
            if (renderingData.cameraData.isSceneViewCamera) return;
           
            //메인 카메라에서만 적용 되게(이부분은 나중에 다르게 적용 가능)
            if (renderingData.cameraData.camera != Camera.main) return;

            //ConfigureInput 함수를 사용하면 아래 pass가 특정 텍스쳐를 사용하며 urp가 특정 텍스쳐를 제작해 준다
            //ScriptableRenderPassInput.Depth 는 뎁스 텍스쳐(_CameraDepthTexture)
            //ScriptableRenderPassInput.Normal 는 월드 노멀 텍스쳐(_CameraNormalsTexture)
            //ScriptableRenderPassInput.Color 는 오파크 텍스쳐(_CameraOpaqueTexture)
            testRenderPass.ConfigureInput(ScriptableRenderPassInput.Depth);

            renderer.EnqueuePass(testRenderPass);
        }

        //에디터 종료 시 초기화 해주는 함수
        //material을 생성하였거나 할 때 메모리누수 를 방지하기 위해 아래 함수에서 제거해줘야 한다
        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
        }
    }

    public class TestRenderPass : ScriptableRenderPass
    {
        //위 renderer feature 클래스에 서 가져올 데이터
        Settings settings;

        //오브젝트 렌더링 오버라이딩 때 사용할 변수들 
        private FilteringSettings filteringSettings;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();


        //패스 이름 같은거 넣어주는 sampler (Frame debugger 에서 확인 가능)
        ProfilingSampler _profilingSampler;

        //Blit(post processing) 할때 사용할 RT
        //RTHandle dstRT;//이건 2022 이상일 떄 사용하는 RT 변수
        RenderTargetHandle dstRT;//이건 2021때 사용하는 RT 변수 인듯

        public TestRenderPass(Settings settings, string samperName)
        {
            this.settings = settings;

            //위 이름의 sampler 생성
            _profilingSampler = new ProfilingSampler(samperName);

            //위 필터 세팅 데이터를 가진 오브젝트만 불러온다
            //현재는 Opaque 오브젝트에 특정 레이어을 가진 오브젝트만 필터링 해 가져옴
            filteringSettings = new FilteringSettings(RenderQueueRange.opaque, settings.layerMask);

            // Use URP's default shader tags
            shaderTagsList.Add(new ShaderTagId("SRPDefaultUnlit"));
            shaderTagsList.Add(new ShaderTagId("UniversalForward"));
            shaderTagsList.Add(new ShaderTagId("UniversalForwardOnly"));

            dstRT.Init("_TestDstRenderTexture");
        }

        // Called before executing the render pass.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            base.OnCameraSetup(cmd, ref renderingData);

            ConfigureTarget(renderingData.cameraData.renderer.cameraColorTarget, renderingData.cameraData.renderer.cameraDepthTarget);
            //ConfigureClear(ClearFlag.Color, new Color(1, 0, 0, 0));
        }

        // Here you can implement the rendering logic.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();

            //아래처럼 ProfilingScope을 선언하면 frame debugger에서 sampler 이름 안에서 정리 됨
            using (new ProfilingScope(cmd, _profilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                /*
                Note : should always ExecuteCommandBuffer at least once before using
                ScriptableRenderContext functions (e.g. DrawRenderers) even if you 
                don't queue any commands! This makes sure the frame debugger displays 
                everything under the correct title. (라고 한다)
                */

                if (settings.blitMaterial != null)
                {
                    //생성할 텍스쳐 정보를 현재 카메라 정보로 사용하기
                    RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
                    descriptor.depthBufferBits = 0;//대신 Depth는 사용하지 않으니 제거하기

                    //임시 렌더 텍스쳐 생성(여기다 Blit 텍스쳐 생성될 예정)
                    cmd.GetTemporaryRT(dstRT.id, descriptor, FilterMode.Bilinear);

                    //카메라 렌더 텍스쳐 가져오기(사실상 화면 이미지)
                    var src = renderingData.cameraData.renderer.cameraColorTarget;

                    //Blit의 기본 사용 방법(scr에서 dst 로 그려주고 다시 dst에서 src로 그려주기)
                    Blit(cmd, src, dstRT.Identifier(), settings.blitMaterial, 0);
                    Blit(cmd, dstRT.Identifier(), src);
                }

                if (settings.useRendererSetting)
                {
                    SortingCriteria sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;

                    DrawingSettings drawingSettings = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                    if (settings.overrideMaterial != null)
                    {
                        drawingSettings.overrideMaterialPassIndex = settings.overrideMaterialPass;
                        drawingSettings.overrideMaterial = settings.overrideMaterial;
                    }

                    context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);
                }

            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            base.OnCameraCleanup(cmd);

            cmd.ReleaseTemporaryRT(dstRT.id);
        }
    }

}