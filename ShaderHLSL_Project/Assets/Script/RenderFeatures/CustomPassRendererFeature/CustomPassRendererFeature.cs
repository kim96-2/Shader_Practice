using System.Collections;
using System.Collections.Generic;
using TestRendererFeature;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomPassRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public List<string> passNames;
        public LayerMask layerMask = 1;
    }

    public class CustomPassRenderPass : ScriptableRenderPass
    {
        Settings settings = new();

        //오브젝트 렌더링 오버라이딩 때 사용할 변수들 
        private FilteringSettings filteringSettings;
        private List<ShaderTagId> shaderTagsList;

        //패스 이름 같은거 넣어주는 sampler (Frame debugger 에서 확인 가능)
        ProfilingSampler _profilingSampler;

        public CustomPassRenderPass(Settings settings, string samplerName) : base()
        {
            this.settings = settings;

            _profilingSampler = new ProfilingSampler(samplerName);

            //setting에 있는 패스 이름에 맞게 패스 id 제작
            shaderTagsList = new List<ShaderTagId>();
            if(settings.passNames != null)
            {
                foreach (string passName in settings.passNames)
                {
                    shaderTagsList.Add(new ShaderTagId(passName));
                }
            }
            

            filteringSettings = new FilteringSettings(RenderQueueRange.all, settings.layerMask);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            base.OnCameraSetup(cmd, ref renderingData);

            //렌더링하는 텍스쳐를 잡아줌(아래는 카메라 컬러 텍스쳐와 카메라 뎁스 텍스쳐에 그리는 부분)
            ConfigureTarget(renderingData.cameraData.renderer.cameraColorTarget, renderingData.cameraData.renderer.cameraDepthTarget);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();

            using (new ProfilingScope(cmd, _profilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                if(shaderTagsList.Count > 0)
                {
                    SortingCriteria sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;

                    DrawingSettings drawingSettings = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);

                    context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            base.OnCameraCleanup(cmd);
        }
    }

    [SerializeField] Settings settings;
    [SerializeField] RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;

    CustomPassRenderPass customPassRenderPass;

    public override void Create()
    {
        customPassRenderPass = new CustomPassRenderPass(settings, name);

        //패스 렌더 순저 정의
        customPassRenderPass.renderPassEvent = renderPassEvent;

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //프리뷰 카메라에서는 적용 안되게 
        if (renderingData.cameraData.isPreviewCamera) return;

        //제작한 패스 렌더러 큐에 넣어줌(이제 적용됨)
        renderer.EnqueuePass(customPassRenderPass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
    }
}
