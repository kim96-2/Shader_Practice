using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public struct Cube
{
    public Vector3 position;
    public Color color;
}

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

public class CumputeShaderCubeController : MonoBehaviour
{
    public ComputeShader computeShader;

    [Space(15f)]
    [SerializeField] int count = 50;
    [SerializeField] GameObject cubePrefab;

    List<CubeObj> cubesObj;

    Cube[] cubeData;

    ComputeBuffer cubesBuffer;

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
        cubesObj = new List<CubeObj>();
        cubeData = new Cube[count * count];

        for (int x = 0; x < count; x++)
        {
            for (int y = 0; y < count; y++)
            {
                CreateCube(x, y);
            }
        }
    }

    void CreateCube(int x, int y)
    {
        GameObject cube = Instantiate(cubePrefab, new Vector3(x, 0, y), Quaternion.identity);

        cubesObj.Add(new CubeObj(cube));

        Cube data = new Cube();
        data.position = cube.transform.position;
        data.color = Color.black;

        cubeData[x * count + y] = data;
    }

    void InitComputeShader()
    {
        int structSize = sizeof(float) * 4 + sizeof(float) * 3;

        cubesBuffer = new ComputeBuffer(cubeData.Length, structSize);

        cubesBuffer.SetData(cubeData);

        computeShader.SetBuffer(0, "cubes", cubesBuffer);
        computeShader.SetInt("_Resolution", count);

        _time = 0;
    }

    void UpdateComputeShader()
    {
        _time += Time.deltaTime;

        computeShader.SetFloat("_Time", _time);

        int groups = Mathf.CeilToInt((float)count / 8f);

        computeShader.Dispatch(0, 1, 1, 1);


        cubesBuffer.GetData(cubeData);

        for (int i = 0; i < cubeData.Length; i++)
        {

            CubeObj cubeObj = cubesObj[i];

            cubeObj.obj.transform.position = cubeData[i].position;
            cubeObj.renderer.material.SetColor("_BaseColor", cubeData[i].color);

        }
    }
}
