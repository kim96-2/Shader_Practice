using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CustomFPSTransform : MonoBehaviour
{
    [SerializeField] Transform rootTransform;

    // Start is called before the first frame update
    void Start()
    {
        FPSManager.Instance.observers.Add(this);

        rootTransform = transform.parent;

        transform.parent = null;
    }

    private void OnDestroy()
    {
        FPSManager.Instance.observers.Remove(this);
    }

    public void CustomUpdate()
    {
        transform.position = rootTransform.position;
        transform.rotation = rootTransform.rotation;
    }
}
