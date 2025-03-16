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

            //렌더링하는 텍스쳐를 잡아줌(아래는 카메라 컬러 텍스쳐와 카메라 뎁스 텍스쳐에 그리는 부분)
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

        //패스 렌더 순저 정의
        stencilLightingPass.renderPassEvent = renderPassEvent;

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //프리뷰 카메라에서는 적용 안되게 
        if (renderingData.cameraData.isPreviewCamera) return;

        //제작한 패스 렌더러 큐에 넣어줌(이제 적용됨)
        renderer.EnqueuePass(stencilLightingPass);
    }
}
