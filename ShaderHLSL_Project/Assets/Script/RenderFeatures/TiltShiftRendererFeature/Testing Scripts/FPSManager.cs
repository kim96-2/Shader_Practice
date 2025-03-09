using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FPSManager : MonoBehaviour
{
    static FPSManager instance;
    public static FPSManager Instance => instance;

    public float fps = 12;
    WaitForSecondsRealtime fpsWait;

    public float timeScale = 1.5f;

    [System.NonSerialized] public List<CustomFPSTransform> observers = new();

    void Awake()
    {
        instance = this;

        StartCoroutine(CustomUpdates());

        Time.timeScale = timeScale;

        fpsWait = new WaitForSecondsRealtime(1f / fps);
    }

    private void OnValidate()
    {
        Time.timeScale = timeScale;

        fpsWait = new WaitForSecondsRealtime(1f / fps);
    }

    IEnumerator CustomUpdates()
    {
        while (true)
        {
            foreach(CustomFPSTransform customTransform in observers)
            {
                customTransform.CustomUpdate();
            }

            yield return fpsWait;
        }
    }
}
