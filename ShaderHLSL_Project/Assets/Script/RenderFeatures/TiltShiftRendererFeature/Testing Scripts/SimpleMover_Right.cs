using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimpleMover_Right : MonoBehaviour
{
    float speed = 10f;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        transform.Translate(Vector3.forward * speed * Time.deltaTime);

        if (transform.position.x > 100f) transform.position = -Vector3.right * 100;
    }
}
