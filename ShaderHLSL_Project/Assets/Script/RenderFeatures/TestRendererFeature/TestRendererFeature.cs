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
    /// �Ʒ� ��ũ ���� ���� �׽�Ʈ Renderer feature
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
            //������ ī�޶󿡼��� ���� �ȵǰ� 
            if (renderingData.cameraData.isPreviewCamera) return;

            //�� �� ī�޶� ������ ���� �ȵǰ�
            if (renderingData.cameraData.isSceneViewCamera) return;
           
            //���� ī�޶󿡼��� ���� �ǰ�(�̺κ��� ���߿� �ٸ��� ���� ����)
            if (renderingData.cameraData.camera != Camera.main) return;

            //ConfigureInput �Լ��� ����ϸ� �Ʒ� pass�� Ư�� �ؽ��ĸ� ����ϸ� urp�� Ư�� �ؽ��ĸ� ������ �ش�
            //ScriptableRenderPassInput.Depth �� ���� �ؽ���(_CameraDepthTexture)
            //ScriptableRenderPassInput.Normal �� ���� ��� �ؽ���(_CameraNormalsTexture)
            //ScriptableRenderPassInput.Color �� ����ũ �ؽ���(_CameraOpaqueTexture)
            testRenderPass.ConfigureInput(ScriptableRenderPassInput.Depth);

            renderer.EnqueuePass(testRenderPass);
        }

        //������ ���� �� �ʱ�ȭ ���ִ� �Լ�
        //material�� �����Ͽ��ų� �� �� �޸𸮴��� �� �����ϱ� ���� �Ʒ� �Լ����� ��������� �Ѵ�
        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
        }
    }

    public class TestRenderPass : ScriptableRenderPass
    {
        //�� renderer feature Ŭ������ �� ������ ������
        Settings settings;

        //������Ʈ ������ �������̵� �� ����� ������ 
        private FilteringSettings filteringSettings;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();


        //�н� �̸� ������ �־��ִ� sampler (Frame debugger ���� Ȯ�� ����)
        ProfilingSampler _profilingSampler;

        //Blit(post processing) �Ҷ� ����� RT
        //RTHandle dstRT;//�̰� 2022 �̻��� �� ����ϴ� RT ����
        RenderTargetHandle dstRT;//�̰� 2021�� ����ϴ� RT ���� �ε�

        public TestRenderPass(Settings settings, string samperName)
        {
            this.settings = settings;

            //�� �̸��� sampler ����
            _profilingSampler = new ProfilingSampler(samperName);

            //�� ���� ���� �����͸� ���� ������Ʈ�� �ҷ��´�
            //����� Opaque ������Ʈ�� Ư�� ���̾��� ���� ������Ʈ�� ���͸� �� ������
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

            //�Ʒ�ó�� ProfilingScope�� �����ϸ� frame debugger���� sampler �̸� �ȿ��� ���� ��
            using (new ProfilingScope(cmd, _profilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                /*
                Note : should always ExecuteCommandBuffer at least once before using
                ScriptableRenderContext functions (e.g. DrawRenderers) even if you 
                don't queue any commands! This makes sure the frame debugger displays 
                everything under the correct title. (��� �Ѵ�)
                */

                if (settings.blitMaterial != null)
                {
                    //������ �ؽ��� ������ ���� ī�޶� ������ ����ϱ�
                    RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
                    descriptor.depthBufferBits = 0;//��� Depth�� ������� ������ �����ϱ�

                    //�ӽ� ���� �ؽ��� ����(����� Blit �ؽ��� ������ ����)
                    cmd.GetTemporaryRT(dstRT.id, descriptor, FilterMode.Bilinear);

                    //ī�޶� ���� �ؽ��� ��������(��ǻ� ȭ�� �̹���)
                    var src = renderingData.cameraData.renderer.cameraColorTarget;

                    //Blit�� �⺻ ��� ���(scr���� dst �� �׷��ְ� �ٽ� dst���� src�� �׷��ֱ�)
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