using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public struct Cube
{
    public Vector3 position;
    public Color color;
}

/*
public class CubeObj
{
    public CubeObj(GameObject obj)
    {
        this.obj = obj;
        this.renderer = obj.GetComponent<Renderer>();
    }

    public GameObject obj;
    public Renderer renderer;
}
*/

public enum KernelFunc
{
    Wave,
    Ripple,
    Sphere,
    Torus
}

public class CumputeShaderCubeController : MonoBehaviour
{
    public ComputeShader computeShader;
    [SerializeField] Material cubeMaterial;

    [Header("Update Settings")]
    const int maxCount = 512;
    [SerializeField, Range(8, maxCount)] int count = 50;
    int prevCount = 0;

    [SerializeField] float radius = 10f;
    //[SerializeField] GameObject cubePrefab;
    [SerializeField] Mesh cubeMesh;
    [SerializeField] KernelFunc kernelFunc;
    int currentKernelFunc;

    //List<CubeObj> cubesObj;

    Cube[] cubeData;

    ComputeBuffer cubesBuffer;

    Bounds bounds;

    float _time = 0;

    // Start is called before the first frame update
    void Start()
    {
        CreateAllCubes();

        InitComputeShader();
    }

    // Update is called once per frame
    void Update()
    {
        UpdateComputeShader();
    }

    void OnDisable()
    {
        cubesBuffer.Dispose();
    }

    void CreateAllCubes()
    {
        //cubesObj = new List<CubeObj>();
        cubeData = new Cube[maxCount * maxCount];

        for (int x = 0; x < maxCount; x++)
        {
            for (int y = 0; y < maxCount; y++)
            {
                CreateCube(x, y);
            }
        }
    }

    void CreateCube(int x, int y)
    {
        //GameObject cube = Instantiate(cubePrefab, new Vector3(x, 0, y), Quaternion.identity);

        //cubesObj.Add(new CubeObj(cube));

        Cube data = new Cube();
        data.position = new Vector3(x, 0, y);
        data.color = Color.black;

        cubeData[x * maxCount + y] = data;
    }

    void InitComputeShader()
    {
        int structSize = sizeof(float) * 4 + sizeof(float) * 3;

        cubesBuffer = new ComputeBuffer(cubeData.Length, structSize);

        cubesBuffer.SetData(cubeData);

        _time = 0;

        bounds = new Bounds(Vector3.zero, Vector3.one * count);

        cubeMaterial.SetBuffer("cubes", cubesBuffer);

        currentKernelFunc = (int)kernelFunc;
    }

    void UpdateComputeShader()
    {
        _time += Time.deltaTime;

        computeShader.SetVector("_Time", new Vector4(_time, Time.deltaTime, 0, 0));
     
        computeShader.SetInt("_Resolution", count);
        computeShader.SetInt("_PrevResolution", prevCount);
        prevCount = count;

        computeShader.SetFloat("_Radius", radius);

        cubeMaterial.SetMatrix("_ModelMatrix", transform.localToWorldMatrix);

        int groups = Mathf.CeilToInt((float)count / 8f);

        if (Input.GetKeyDown(KeyCode.LeftArrow))
        {
            currentKernelFunc = (currentKernelFunc - 1 + 4) % 4;
        }
        else if (Input.GetKeyDown(KeyCode.RightArrow))
        {
            currentKernelFunc = (currentKernelFunc + 1 + 4) % 4;
        }

        computeShader.SetInt("_FuncIndex", currentKernelFunc);

        computeShader.SetBuffer(0, "cubes", cubesBuffer);
        computeShader.Dispatch(0, groups, groups, 1);

        /*
        cubesBuffer.GetData(cubeData);

        for (int i = 0; i < cubeData.Length; i++)
        {

            CubeObj cubeObj = cubesObj[i];

            cubeObj.obj.transform.position = cubeData[i].position;
            cubeObj.renderer.material.SetColor("_BaseColor", cubeData[i].color);

        }
        */

        Graphics.DrawMeshInstancedProcedural(cubeMesh, 0, cubeMaterial, bounds, count * count);
    }
}
