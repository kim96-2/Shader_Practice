using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ComputeGrassManager : MonoBehaviour
{
    struct GrassData
    {
        public Vector3 position;
    }
    const int SIZE_GRASSDATA = 3 * sizeof(float);
    const int SIZE_ARGS = 5 * sizeof(uint);

    [Header("Grass Setting")]
    [SerializeField] float fieldSize = 100f;
    [SerializeField] int grassCount = 1000;

    [SerializeField] Material grassMaterial;
    [SerializeField] Mesh grassMesh;


    [Space(10f)]
    [SerializeField] ComputeShader grassCullingComputeShader;

    ComputeBuffer totalGrassBuffer, culledGrassBuffer;

    private ComputeBuffer voteBuffer, scanBuffer, groupSumArrayBuffer, scannedGroupSumBuffer;

    uint[] args;
    ComputeBuffer argsBuffer;


    Bounds grassBounds;

    int numThreadGroups, numVoteThreadGroups, numGroupScanThreadGroups;

    void Start()
    {
        InitCullData();
        InitGrassData();
        InitMaterial();
    }

    void Update()
    {
        UpdateGrassRendering();
    }

    void OnDisable()
    {
        argsBuffer?.Release();

        totalGrassBuffer?.Release();
        culledGrassBuffer?.Release();

        voteBuffer?.Release();
        scanBuffer?.Release();
        groupSumArrayBuffer?.Release();
        scannedGroupSumBuffer?.Release();
    }

    void InitGrassData()
    {

        totalGrassBuffer = new ComputeBuffer(grassCount * grassCount, SIZE_GRASSDATA);
        culledGrassBuffer = new ComputeBuffer(grassCount * grassCount, SIZE_GRASSDATA);

        GrassData[] grassDatas = new GrassData[grassCount * grassCount];

        for (int y = 0; y < grassCount; y++)
        {
            for (int x = 0; x < grassCount; x++)
            {
                Vector3 pos = new Vector3(
                    x * fieldSize / (float)grassCount - fieldSize / 2f,
                    0,
                    y * fieldSize / (float)grassCount - fieldSize / 2f
                );

                //grassDatas[y * grassCount + x].position = Vector3.zero;
                grassDatas[y * grassCount + x].position = pos;
            }
        }

        totalGrassBuffer.SetData(grassDatas);

        argsBuffer = new ComputeBuffer(1, SIZE_ARGS, ComputeBufferType.IndirectArguments);

        args = new uint[5];
        args[0] = (uint)grassMesh.GetIndexCount(0);
        args[1] = (uint)0;
        args[2] = (uint)grassMesh.GetIndexStart(0);
        args[3] = (uint)grassMesh.GetBaseVertex(0);
        argsBuffer.SetData(args);

        grassBounds = new Bounds(Vector3.zero, new Vector3(fieldSize * 1.2f, 100f, fieldSize * 1.2f));
        //grassBounds = new Bounds(Vector3.zero, 100f * Vector3.one);

    }

    void InitCullData()
    {
        uint threadX;
        grassCullingComputeShader.GetKernelThreadGroupSizes(0, out threadX, out _, out _);
        float voteThread = (float)threadX;

        numThreadGroups = Mathf.CeilToInt((grassCount * grassCount) / voteThread);

        if (numThreadGroups > voteThread)
        {
            int powerOfTwo = (int)voteThread;
            while (powerOfTwo < numThreadGroups)
                powerOfTwo *= 2;

            numThreadGroups = powerOfTwo;
        }
        else
        {
            while (voteThread % numThreadGroups != 0)
                numThreadGroups++;
        }


        grassCullingComputeShader.GetKernelThreadGroupSizes(1, out threadX, out _, out _);
        float scanThread = (float)threadX * 2;
        numVoteThreadGroups = Mathf.CeilToInt(grassCount * grassCount / scanThread);

        grassCullingComputeShader.GetKernelThreadGroupSizes(2, out threadX, out _, out _);
        float groupScanThread = (float)threadX;
        numGroupScanThreadGroups = Mathf.CeilToInt(grassCount * grassCount / groupScanThread);

        int _size = sizeof(uint);
        voteBuffer = new ComputeBuffer(grassCount * grassCount, _size);
        scanBuffer = new ComputeBuffer(grassCount * grassCount, _size);
        groupSumArrayBuffer = new ComputeBuffer(numThreadGroups, _size);
        scannedGroupSumBuffer = new ComputeBuffer(numThreadGroups, _size);

        Debug.Log(numThreadGroups + " " + voteThread);
        Debug.Log(numVoteThreadGroups + " " + scanThread);
        Debug.Log(numGroupScanThreadGroups + " " + groupScanThread);

    }

    void InitMaterial()
    {
        grassMaterial.SetBuffer("_GrassBuffer", culledGrassBuffer);
    }

    void UpdateGrassRendering()
    {
        CullGrass();

        Graphics.DrawMeshInstancedIndirect(grassMesh, 0, grassMaterial, grassBounds, argsBuffer);

        //uint[] temp = new uint[5];
        //argsBuffer.GetData(temp);
        //Graphics.DrawMeshInstancedProcedural(grassMesh, 0, grassMaterial, grassBounds, (int)temp[1]);
    }

    void CullGrass()
    {
        argsBuffer.SetData(args);

        Matrix4x4 P = Camera.main.projectionMatrix;
        Matrix4x4 V = Camera.main.transform.worldToLocalMatrix;
        Matrix4x4 VP = P * V;

        //Vote
        grassCullingComputeShader.SetMatrix("Matrix_VP", VP);
        grassCullingComputeShader.SetBuffer(0, "_GrassDataBuffer", totalGrassBuffer);
        grassCullingComputeShader.SetBuffer(0, "_VoteBuffer", voteBuffer);
        grassCullingComputeShader.Dispatch(0, numVoteThreadGroups, 1, 1);

        //Scan In Groups
        grassCullingComputeShader.SetBuffer(1, "_VoteBuffer", voteBuffer);
        grassCullingComputeShader.SetBuffer(1, "_ScanBuffer", scanBuffer);
        grassCullingComputeShader.SetBuffer(1, "_GroupSumArray", groupSumArrayBuffer);
        grassCullingComputeShader.Dispatch(1, numThreadGroups, 1, 1);

        // Scan Groups
        grassCullingComputeShader.SetInt("_NumGroups", numVoteThreadGroups);
        grassCullingComputeShader.SetBuffer(2, "_GroupSumArrayIn", groupSumArrayBuffer);
        grassCullingComputeShader.SetBuffer(2, "_GroupSumArrayOut", scannedGroupSumBuffer);
        grassCullingComputeShader.Dispatch(2, numGroupScanThreadGroups, 1, 1);

        // Compact
        grassCullingComputeShader.SetBuffer(3, "_GrassDataBuffer", totalGrassBuffer);
        grassCullingComputeShader.SetBuffer(3, "_VoteBuffer", voteBuffer);
        grassCullingComputeShader.SetBuffer(3, "_ScanBuffer", scanBuffer);
        grassCullingComputeShader.SetBuffer(3, "_ArgsBuffer", argsBuffer);
        grassCullingComputeShader.SetBuffer(3, "_CulledGrassOutputBuffer", culledGrassBuffer);
        grassCullingComputeShader.SetBuffer(3, "_GroupSumArray", scannedGroupSumBuffer);
        grassCullingComputeShader.Dispatch(3, numVoteThreadGroups, 1, 1);

        //uint threadX;
        //grassCullingComputeShader.GetKernelThreadGroupSizes(3, out threadX, out _, out _);
        //int groupScanThread = (int)threadX;
        //Debug.Log(numThreadGroups + " * " + (int)threadX + " = " + (int)threadX * numThreadGroups);

        //uint[] temp = new uint[5];
        //argsBuffer.GetData(temp);
        //Debug.Log(temp[1] + " " + args[1]);
    }
}
