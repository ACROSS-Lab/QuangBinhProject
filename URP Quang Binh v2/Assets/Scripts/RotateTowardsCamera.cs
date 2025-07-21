using UnityEngine;

public class RotateTowardsCamera : MonoBehaviour
{
    Transform camTransform;
    

    void Start()
    {
        camTransform = Camera.main.transform;
        Debug.Log("camTransform: " + camTransform);

        if (camTransform == null)
        {
            GameObject cam = GameObject.FindGameObjectWithTag("MainCamera");
            if (cam != null)
            {
                camTransform = cam.transform;
            }
        }

        
    }

    void Update()
    {
        Vector3 currentRotation = transform.eulerAngles;

        Vector3 directionToCamera = camTransform.position - transform.position;
        directionToCamera.y = 0;

        Quaternion targetRotation = Quaternion.LookRotation(directionToCamera);
        transform.rotation = Quaternion.Euler(currentRotation.x, targetRotation.eulerAngles.y, currentRotation.z);
    }
}
