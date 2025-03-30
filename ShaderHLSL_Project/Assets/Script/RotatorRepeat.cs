using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotatorRepeat : MonoBehaviour
{
    public float rotateSpeed = 10f;
    public float rotateAmount = 45f;

    Vector3 defaultAngle;

    // Start is called before the first frame update
    void Start()
    {
        defaultAngle = transform.rotation.eulerAngles;
    }

    // Update is called once per frame
    void Update()
    {
        transform.rotation = Quaternion.Euler(
            defaultAngle.x,
            defaultAngle.y + Mathf.Sin(rotateSpeed * Time.time) * rotateAmount,
            defaultAngle.z);
    }
}
