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

    [Header("TransitionSetting")]
    [SerializeField] float transitionDuration = 2f;
    bool transitioning;

    [Header("Update Settings")]
    const int maxCount = 512;
    [SerializeField, Range(8, maxCount)] int count = 50;
    [SerializeField] float radius = 10f;
    //[SerializeField] GameObject cubePrefab;
    [SerializeField] Mesh cubeMesh;
    //[SerializeField] KernelFunc kernelFunc;
    int currentKernelFunc;
    int nextKernelFunc;

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

        //currentKernelFunc = (int)kernelFunc;
        StartCoroutine(ChangeRandomKernelFunc());
    }

    void UpdateComputeShader()
    {
        _time += Time.deltaTime;

        computeShader.SetFloat("_Time", _time);
        computeShader.SetInt("_Resolution", count);
        computeShader.SetFloat("_Radius", radius);
        computeShader.SetMatrix("_ModelMatrix", transform.localToWorldMatrix);

        int groups = Mathf.CeilToInt((float)count / 8f);
        /*
        int current = currentKernelFunc;
        if (Input.GetKeyDown(KeyCode.LeftArrow))
        {
            currentKernelFunc = (currentKernelFunc - 1 + 4) % 4;
        }
        else if (Input.GetKeyDown(KeyCode.RightArrow))
        {
            currentKernelFunc = (currentKernelFunc + 1 + 4) % 4;
        }
        int kernelIndex = current + currentKernelFunc * 4;
        */

        int kernelIndex = currentKernelFunc + nextKernelFunc * 4;

        computeShader.SetBuffer(kernelIndex, "cubes", cubesBuffer);
        computeShader.Dispatch(kernelIndex, groups, groups, 1);

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

    IEnumerator ChangeRandomKernelFunc()
    {
        currentKernelFunc = Random.Range(0, 4);
        nextKernelFunc = currentKernelFunc;

        yield return new WaitForSeconds(4f);

        while (true)
        {
            nextKernelFunc = (currentKernelFunc + Random.Range(1, 4)) % 4;

            Debug.Log(currentKernelFunc + " to " + nextKernelFunc);

            yield return StartCoroutine(Transition());

            currentKernelFunc = nextKernelFunc;

            Debug.Log(currentKernelFunc + " to " + nextKernelFunc + "end");

            yield return new WaitForSeconds(4f);
        }
    }

    Coroutine transitionCoroutine;

    void StartCoroutine()
    {
        if (transitionCoroutine != null)
            StopCoroutine(transitionCoroutine);

        transitionCoroutine = StartCoroutine(Transition());
    }

    IEnumerator Transition()
    {
        float _time = 0;

        while (_time < transitionDuration)
        {
            computeShader.SetFloat("_TransitionProgress", Mathf.SmoothStep(1f, 0f, _time / transitionDuration));

            _time += Time.deltaTime;

            yield return null;
        }

        yield break;
    }
}
