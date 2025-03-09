using System.Collections;
using System.Collections.Generic;
using TestRendererFeature;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static CustomPassRendererFeature;

public class TiltShiftRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public Material material;
    }

    public class TiltShiftRenderPass : ScriptableRenderPass
    {
        Settings settings;

        ProfilingSampler _profilingSampler;

        RenderTargetHandle dstRT;

        public TiltShiftRenderPass(Settings settings, string samplerName)
        {
            this.settings = settings;

            _profilingSampler = new ProfilingSampler(samplerName);

            dstRT.Init("_DstRenderTexture");
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            base.OnCameraSetup(cmd, ref renderingData);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            base.Configure(cmd, cameraTextureDescriptor);

            //Render Texture ����
            RenderTextureDescriptor descriptor = cameraTextureDescriptor;
            descriptor.depthBufferBits = 0;
            cmd.GetTemporaryRT(dstRT.id, descriptor, FilterMode.Bilinear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();

            using (new ProfilingScope(cmd, _profilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                if(settings.material != null)
                {

                    //ī�޶� RT ��������
                    var src = renderingData.cameraData.renderer.cameraColorTarget;

                    //2 pass blur�� ���� 0��, 1�� pass�� blur ���
                    Blit(cmd, src, dstRT.Identifier(), settings.material, 0);
                    Blit(cmd, dstRT.Identifier(), src, settings.material, 1);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);

        }
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            base.OnCameraCleanup(cmd);

            cmd.ReleaseTemporaryRT(dstRT.id);
        }
    }

    [SerializeField] Settings settings;
    [SerializeField] RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;

    TiltShiftRenderPass tiltShiftRenderPass;

    public override void Create()
    {
        tiltShiftRenderPass = new TiltShiftRenderPass(settings, "Tilt Shift Pass");

        tiltShiftRenderPass.renderPassEvent = this.renderPassEvent;

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //�� �� ī�޶� ������ ���� �ȵǰ�
        //if (renderingData.cameraData.isSceneViewCamera) return;

        //ConfigureInput �Լ��� ����ϸ� �Ʒ� pass�� Ư�� �ؽ��ĸ� ����ϸ� urp�� Ư�� �ؽ��ĸ� ������ �ش�
        tiltShiftRenderPass.ConfigureInput(ScriptableRenderPassInput.Depth);

        //������ �н� ������ ť�� �־���(���� �����)
        renderer.EnqueuePass(tiltShiftRenderPass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
    }
}
