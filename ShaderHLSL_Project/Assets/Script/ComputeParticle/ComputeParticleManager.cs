using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ComputeParticleManager : MonoBehaviour
{
    struct Particle
    {
        public Vector3 position;
        public Vector3 velocity;
        public float life;
    }

    const int SIZE_PARTICLE = 7 * sizeof(float);

    [SerializeField] Mesh particleMesh;
    [SerializeField] Material particleMaterial;
    [SerializeField] int count;
    [SerializeField] ComputeShader computeShader;

    [Space(15f)]
    [SerializeField] Transform target;
    

    ComputeBuffer particleBuffer;
    int kernelID;

    int groupSize;

    RenderParams rp;
    Bounds bounds;

    void Start()
    {
        InitParticle();
    }

    void Update()
    {
        UpdateParticle();
    }

    void OnDisable()
    {
        if (particleBuffer != null)
            particleBuffer.Release();
    }

    void InitParticle()
    {
        Particle[] particles = new Particle[count];

        for (int i = 0; i < count; i++)
        {
            float x = Random.Range(-1f, 1f);
            float y = Random.Range(-1f, 1f);
            float z = Random.Range(-1f, 1f);
            Vector3 pos = new Vector3(x, y, z);
            pos.Normalize();

            pos *= Random.value * 5f;

            particles[i].position = pos;
            particles[i].velocity = Vector3.zero;

            particles[i].life = Random.value * 5.0f + 1.0f;
        }

        particleBuffer = new ComputeBuffer(count, SIZE_PARTICLE);
        particleBuffer.SetData(particles);

        kernelID = computeShader.FindKernel("CSMain");

        uint threadX;
        computeShader.GetKernelThreadGroupSizes(kernelID, out threadX, out _, out _);
        groupSize = Mathf.CeilToInt((float)count / (float)threadX);

        computeShader.SetBuffer(kernelID, "_ParticleBuffer", particleBuffer);
        particleMaterial.SetBuffer("_ParticleBuffer", particleBuffer);

        rp = new RenderParams(particleMaterial);
        rp.worldBounds = new Bounds(Vector3.zero, 1000f * Vector3.one);
        bounds = rp.worldBounds;
    }

    void UpdateParticle()
    {
        Vector3 pos = target.position;

        computeShader.SetFloat("_Time", Time.deltaTime);
        computeShader.SetVector("_TargetPosition", new Vector4(pos.x, pos.y, pos.z, 1));

        computeShader.Dispatch(kernelID, groupSize, 1, 1);

        //Graphics.RenderPrimitives(rp, MeshTopology.Points, 1, count);
        Graphics.DrawMeshInstancedProcedural(particleMesh, 0, particleMaterial, bounds, count);
    }
}
