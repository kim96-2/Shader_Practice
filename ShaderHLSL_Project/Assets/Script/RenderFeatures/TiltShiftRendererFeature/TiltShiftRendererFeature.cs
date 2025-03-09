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

            //Render Texture 제작
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

                    //카메라 RT 가져오기
                    var src = renderingData.cameraData.renderer.cameraColorTarget;

                    //2 pass blur를 위해 0번, 1번 pass로 blur 사용
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
        //씬 뷰 카메라 에서도 적용 안되게
        //if (renderingData.cameraData.isSceneViewCamera) return;

        //ConfigureInput 함수를 사용하면 아래 pass가 특정 텍스쳐를 사용하며 urp가 특정 텍스쳐를 제작해 준다
        tiltShiftRenderPass.ConfigureInput(ScriptableRenderPassInput.Depth);

        //제작한 패스 렌더러 큐에 넣어줌(이제 적용됨)
        renderer.EnqueuePass(tiltShiftRenderPass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
    }
}
