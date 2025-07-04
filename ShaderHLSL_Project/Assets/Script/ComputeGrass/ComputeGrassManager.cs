using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

public class ComputeGrassManager : MonoBehaviour
{
    struct GrassData
    {
        public Vector3 position;
        public Vector3 windDirection;
    }
    readonly int SIZE_GRASSDATA = Marshal.SizeOf(typeof(GrassData));
    const int SIZE_ARGS = 5 * sizeof(uint);

    [Header("Grass Setting")]
    [SerializeField] float fieldSize = 100f;
    [SerializeField] int grassCount = 1000;

    [SerializeField] Material grassMaterial;
    [SerializeField] Mesh grassMesh;

    [Header("Wind Setting")]
    [SerializeField] ComputeShader windComputeShader;
    [SerializeField] float mainWindFrequancy = 1f;
    [SerializeField] float mainWindAmplitude = 1f;
    [SerializeField] float turbPower = 2.3f;
    [SerializeField] float turbSize = 3.0f;

    [SerializeField, Range(0f, 360f)] float mainWindAngle;


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
        InitWind();
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
                    (x + Random.value * 1f) * fieldSize / (float)grassCount - fieldSize / 2f,
                    0,
                    (y + Random.value * 1f) * fieldSize / (float)grassCount - fieldSize / 2f
                );

                // Vector3 pos = new Vector3(
                //     x + Random.value * 0.05f,
                //     0,
                //     y + Random.value * 0.05f
                // );
                // pos *= fieldSize / (float)grassCount - fieldSize / 2f;

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
        grassCullingComputeShader.GetKernelThreadGroupSizes(1, out threadX, out _, out _);
        float scanThread = (float)threadX * 2;

        numThreadGroups = Mathf.CeilToInt((grassCount * grassCount) / scanThread);

        if (numThreadGroups > scanThread)
        {
            int powerOfTwo = (int)scanThread;
            while (powerOfTwo < numThreadGroups)
                powerOfTwo *= 2;

            numThreadGroups = powerOfTwo;
        }
        else
        {
            while (scanThread % numThreadGroups != 0)
                numThreadGroups++;
        }


        grassCullingComputeShader.GetKernelThreadGroupSizes(0, out threadX, out _, out _);
        float voteThread = (float)threadX;
        numVoteThreadGroups = Mathf.CeilToInt(grassCount * grassCount / voteThread);

        grassCullingComputeShader.GetKernelThreadGroupSizes(2, out threadX, out _, out _);
        float groupScanThread = (float)threadX * 2;
        numGroupScanThreadGroups = Mathf.CeilToInt(numVoteThreadGroups / groupScanThread);

        int _size = sizeof(uint);
        voteBuffer = new ComputeBuffer(grassCount * grassCount, _size);
        scanBuffer = new ComputeBuffer(grassCount * grassCount, _size);
        groupSumArrayBuffer = new ComputeBuffer(numThreadGroups, _size);
        scannedGroupSumBuffer = new ComputeBuffer(numThreadGroups, _size);

        Debug.Log(numVoteThreadGroups + " " + voteThread);
        Debug.Log(numThreadGroups + " " + scanThread);
        Debug.Log(numGroupScanThreadGroups + " " + groupScanThread);

    }

    void InitMaterial()
    {
        grassMaterial.SetBuffer("_GrassBuffer", culledGrassBuffer);
        //grassMaterial.SetBuffer("_GrassBuffer", totalGrassBuffer);
    }

    void InitWind()
    {
        //windComputeShader.SetBuffer(0, "_GrassDataBuffer", culledGrassBuffer);
        windComputeShader.SetBuffer(0, "_GrassDataBuffer", totalGrassBuffer);
    }

    void UpdateGrassRendering()
    {
        UpdateWind();
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
        grassCullingComputeShader.SetInt("_NumGroups", numThreadGroups);
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
        grassCullingComputeShader.Dispatch(3, numThreadGroups, 1, 1);

        //uint threadX;
        //grassCullingComputeShader.GetKernelThreadGroupSizes(3, out threadX, out _, out _);
        //int groupScanThread = (int)threadX;
        //Debug.Log(numThreadGroups + " * " + (int)threadX + " = " + (int)threadX * numThreadGroups);

        //uint[] temp = new uint[5];
        //argsBuffer.GetData(temp);
        //Debug.Log(temp[1] + " " + args[1]);
    }

    void UpdateWind()
    {
        windComputeShader.SetFloat("_Frequency", mainWindFrequancy);
        windComputeShader.SetFloat("_Amplitude", mainWindAmplitude);

        windComputeShader.SetFloat("_TurbPower", turbPower);
        windComputeShader.SetFloat("_TurbSize", turbSize);

        Vector3 mainWindDir = Quaternion.Euler(0, mainWindAngle, 0) * Vector3.forward;
        Vector4 wind = new Vector4(mainWindDir.x, mainWindDir.y, mainWindDir.z, 0);
        windComputeShader.SetVector("_MainWindDir", wind);

        windComputeShader.SetFloat("_Time", Time.time);

        uint[] temp = new uint[5];
        argsBuffer.GetData(temp);

        int groupSize = Mathf.CeilToInt((float)(grassCount * grassCount) / 128);
        windComputeShader.Dispatch(0, groupSize, 1, 1);

    }
}
