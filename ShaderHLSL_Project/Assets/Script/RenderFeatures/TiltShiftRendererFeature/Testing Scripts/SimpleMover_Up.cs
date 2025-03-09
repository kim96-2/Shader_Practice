using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimpleMover_Up : MonoBehaviour
{
    float speed = 10f;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        transform.Translate(transform.forward * speed * Time.deltaTime, Space.World);

        if (Vector3.Dot(transform.position - new Vector3(100,0,63), transform.forward) > 50f) transform.position -= transform.forward * 100f;

        Debug.DrawRay(transform.position, transform.forward * 10f, Color.red);
    }
}
