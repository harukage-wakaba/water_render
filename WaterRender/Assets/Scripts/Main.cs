using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Main : MonoBehaviour
{
    Camera _main_camera;

    // Start is called before the first frame update
    void Start()
    {
        Screen.SetResolution(800,600,Screen.fullScreen);
        _main_camera = this.GetComponent<Camera>();
    }

    // Update is called once per frame
    void FixedUpdate()
    {
        // カメラの回転
        FixedUpdateCameraAnim();
    }

    void FixedUpdateCameraAnim()
    {
        var pos = Quaternion.Euler(0,0.1f,0)* this.transform.position;
        this.transform.position = pos;
        _main_camera.transform.LookAt( new Vector3(0,1.0f,0) );
    }
}
