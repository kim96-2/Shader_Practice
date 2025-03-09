using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BasicCameraMover : MonoBehaviour
{
    Vector3 offset;

    public float moveSpeed = 20f;

    // Start is called before the first frame update
    void Start()
    {
        offset = this.transform.position - GameObject.FindWithTag("Player").transform.position;
    }

    // Update is called once per frame
    void LateUpdate()
    {
        Vector3 pos = GameObject.FindWithTag("Player").transform.position + offset;

        transform.position = Vector3.Lerp(transform.position, pos, moveSpeed * Time.deltaTime);
    }
}
