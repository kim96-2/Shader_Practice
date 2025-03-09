using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class FrameRateController : MonoBehaviour
{
    public int gameFPS = 100;

    public int renderFPS = 30;

    // Start is called before the first frame update
    void Start()
    {
        Application.targetFrameRate = gameFPS;
        OnDemandRendering.renderFrameInterval = gameFPS / renderFPS;
    }

    private void OnValidate()
    {
        Application.targetFrameRate = gameFPS;
        OnDemandRendering.renderFrameInterval = gameFPS / renderFPS;
    }
}
