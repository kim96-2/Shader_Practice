using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;
using UnityEngine.Rendering.Universal;
using static CustomPassRendererFeature;

public class StencilLightingRendererFeature : ScriptableRendererFeature
{

    public class StencilLightingPass : ScriptableRenderPass
    {
        ProfilingSampler _mask1Sampler;
        ProfilingSampler _mask2Sampler;
        ProfilingSampler _outsideSampler;

        ShaderTagId mask1TagId;
        ShaderTagId mask2TagId;
        ShaderTagId outsideTagId;

        List<ShaderTagId> tagIds;

        private FilteringSettings filteringSettings;

        public StencilLightingPass()
        {
            _mask1Sampler = new ProfilingSampler("Mask 1 Pass");
            _mask2Sampler = new ProfilingSampler("Mask 2 Pass");
            _outsideSampler = new ProfilingSampler("Outside Pass");

            mask1TagId = new ShaderTagId("StencilMask_1");
            mask2TagId = new ShaderTagId("StencilMask_2");
            outsideTagId = new ShaderTagId("StencilOutside");

            tagIds = new List<ShaderTagId>();
            tagIds.Add(mask1TagId);
            tagIds.Add(outsideTagId);

            filteringSettings = new FilteringSettings(RenderQueueRange.all);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            base.OnCameraSetup(cmd, ref renderingData);

            //�������ϴ� �ؽ��ĸ� �����(�Ʒ��� ī�޶� �÷� �ؽ��Ŀ� ī�޶� ���� �ؽ��Ŀ� �׸��� �κ�)
            //ConfigureTarget(renderingData.cameraData.renderer.cameraColorTarget, renderingData.cameraData.renderer.cameraDepthTarget);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();

            SortingCriteria sortingCriteria = SortingCriteria.CommonTransparent;

            
            using (new ProfilingScope(cmd, _mask1Sampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                DrawingSettings drawingSettings = CreateDrawingSettings(tagIds, ref renderingData, sortingCriteria);

                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);

            }
            

            /*
            using (new ProfilingScope(cmd, _mask1Sampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
            
                DrawingSettings drawingSettings = CreateDrawingSettings(mask1TagId, ref renderingData, sortingCriteria);

                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);

            }

            using (new ProfilingScope(cmd, _outsideSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                DrawingSettings drawingSettings = CreateDrawingSettings(outsideTagId, ref renderingData, sortingCriteria);

                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);

            }
            */

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

    }

    [SerializeField] RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;

    StencilLightingPass stencilLightingPass;

    public override void Create()
    {
        stencilLightingPass = new StencilLightingPass();

        //�н� ���� ���� ����
        stencilLightingPass.renderPassEvent = renderPassEvent;

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //������ ī�޶󿡼��� ���� �ȵǰ� 
        if (renderingData.cameraData.isPreviewCamera) return;

        //������ �н� ������ ť�� �־���(���� �����)
        renderer.EnqueuePass(stencilLightingPass);
    }
}
