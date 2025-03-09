using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FrameRateController : MonoBehaviour
{
    public int fps = 30;

    // Start is called before the first frame update
    void Start()
    {
        Application.targetFrameRate = fps;
    }

    private void OnValidate()
    {
        Application.targetFrameRate = fps;
    }
}
