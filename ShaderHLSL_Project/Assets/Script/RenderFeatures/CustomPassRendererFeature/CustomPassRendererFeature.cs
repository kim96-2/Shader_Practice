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

        //������Ʈ ������ �������̵� �� ����� ������ 
        private FilteringSettings filteringSettings;
        private List<ShaderTagId> shaderTagsList;

        //�н� �̸� ������ �־��ִ� sampler (Frame debugger ���� Ȯ�� ����)
        ProfilingSampler _profilingSampler;

        public CustomPassRenderPass(Settings settings, string samplerName) : base()
        {
            this.settings = settings;

            _profilingSampler = new ProfilingSampler(samplerName);

            //setting�� �ִ� �н� �̸��� �°� �н� id ����
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

            //�������ϴ� �ؽ��ĸ� �����(�Ʒ��� ī�޶� �÷� �ؽ��Ŀ� ī�޶� ���� �ؽ��Ŀ� �׸��� �κ�)
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

        //�н� ���� ���� ����
        customPassRenderPass.renderPassEvent = renderPassEvent;

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //������ ī�޶󿡼��� ���� �ȵǰ� 
        if (renderingData.cameraData.isPreviewCamera) return;

        //������ �н� ������ ť�� �־���(���� �����)
        renderer.EnqueuePass(customPassRenderPass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
    }
}
