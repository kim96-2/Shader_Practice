using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class ComputeParticleManager : MonoBehaviour
{
    struct Particle
    {
        public Vector3 position;
        public Vector3 velocity;
        public float headAmount;
        public float colorAmount;
    }

    struct Obstacle
    {
        public Vector3 position;
        public float size;
    }

    const int SIZE_PARTICLE = 8 * sizeof(float);
    const int SIZE_OBSTACLE = 4 * sizeof(float);

    [SerializeField] Mesh particleMesh;
    [SerializeField] Material particleMaterial;
    [SerializeField] int count;
    [SerializeField] ComputeShader computeShader;

    [Space(10f)]
    [SerializeField] AnimationCurve headAmountCurve;

    [Header("Update Setting")]
    [SerializeField] float nearRadius = 10f;
    [SerializeField, Range(0f, 10f)] float separationAmount = 1f;
    [SerializeField, Range(0f, 10f)] float alignmentAmount = 1f;
    [SerializeField, Range(0f, 10f)] float cohesionAmount = 1f;

    [Space(10f)]
    [SerializeField, Range(0f, 100f)] float randomPowerAmount = 10f;

    [Space(10f)]
    [SerializeField] Transform mainBoundaryTransform;

    [Space(10f)]
    [SerializeField] Transform obstaclesTransform;

    ComputeBuffer particleBuffer;

    ComputeBuffer obstacleBuffer;

    int kernelID;
    int groupSize;

    RenderParams rp;
    Bounds bounds;

    void Start()
    {
        InitParticle();
        InitObstacle();
    }

    void Update()
    {
        UpdateObstacle();
        UpdateParticle();      
    }

    void OnDisable()
    {
        if (particleBuffer != null)
            particleBuffer.Release();

        if (obstacleBuffer != null)
            obstacleBuffer.Release();
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

            particles[i].position = pos.normalized * Random.value * mainBoundaryTransform.localScale.x / 4f;
            particles[i].velocity = Random.rotation * Vector3.forward * Random.Range(5f, 10f);
            particles[i].headAmount = headAmountCurve.Evaluate(Random.value);

            particles[i].colorAmount = Random.value;
        }

        particleBuffer = new ComputeBuffer(count, SIZE_PARTICLE);
        particleBuffer.SetData(particles);

        kernelID = computeShader.FindKernel("CSMain");

        uint threadX;
        computeShader.GetKernelThreadGroupSizes(kernelID, out threadX, out _, out _);
        groupSize = Mathf.CeilToInt((float)count / (float)threadX);

        computeShader.SetBuffer(kernelID, "_ParticleBuffer", particleBuffer);
        particleMaterial.SetBuffer("_ParticleBuffer", particleBuffer);

        computeShader.SetInt("_ParticleCount", count);

        rp = new RenderParams(particleMaterial);
        rp.worldBounds = new Bounds(Vector3.zero, 100f * Vector3.one);
        bounds = rp.worldBounds;
    }

    void UpdateParticle()
    {

        computeShader.SetVector("_Time", new Vector4(Time.time, Time.deltaTime, 0, 0));
        computeShader.SetFloat("_NearRadius", nearRadius);

        computeShader.SetVector("_SACParams", new Vector4(separationAmount, alignmentAmount, cohesionAmount, 0));

        computeShader.SetFloat("_RandomPowerAmount", randomPowerAmount);

        computeShader.SetVector("_MainBoundary", new Vector4(mainBoundaryTransform.position.x, mainBoundaryTransform.position.y, mainBoundaryTransform.position.z, mainBoundaryTransform.localScale.x / 2f));

        computeShader.Dispatch(kernelID, groupSize, 1, 1);

        //Graphics.RenderPrimitives(rp, MeshTopology.Points, 1, count);
        Graphics.DrawMeshInstancedProcedural(particleMesh, 0, particleMaterial, bounds, count);
    }

    void InitObstacle()
    {
        List<Obstacle> obstacles = new List<Obstacle>();
        foreach (Transform tr in obstaclesTransform)
        {
            Obstacle obs = new Obstacle();
            obs.position = tr.position;
            obs.size = tr.localScale.x / 2f;
            obstacles.Add(obs);

            //Debug.Log(obs.position + " " + obs.size);
        }

        Obstacle[] obstaclesArray = obstacles.ToArray();

        obstacleBuffer = new ComputeBuffer(obstaclesArray.Length, SIZE_OBSTACLE);
        obstacleBuffer.SetData(obstaclesArray);

        computeShader.SetBuffer(kernelID, "_ObsticleBuffer", obstacleBuffer);
        computeShader.SetInt("_ObsticleCount", obstaclesArray.Length);
    }

    void UpdateObstacle()
    {
        List<Obstacle> obstacles = new List<Obstacle>();
        foreach (Transform tr in obstaclesTransform)
        {
            Obstacle obs = new Obstacle();
            obs.position = tr.position;
            obs.size = tr.localScale.x / 2f;
            obstacles.Add(obs);
        }

        Obstacle[] obstaclesArray = obstacles.ToArray();

        obstacleBuffer.SetData(obstaclesArray);
    }
}
