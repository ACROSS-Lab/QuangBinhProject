using UnityEngine;

public class CanvasFollower : MonoBehaviour
{
    [SerializeField] Vector3 distanceFromCamera = new Vector3(0, 0, 6);
    [SerializeField] float yRotationOffset = 0;
    [SerializeField] float followSpeed = 8.0f;

    Transform cameraTransform;

    void OnEnable()
    {
        cameraTransform = Camera.main.transform;

        Vector3 targetPosition = cameraTransform.position + (cameraTransform.forward * distanceFromCamera.z) + (cameraTransform.right * distanceFromCamera.x);
        targetPosition.y = cameraTransform.position.y + distanceFromCamera.y;
        transform.position = targetPosition;

        float cameraYaw = cameraTransform.eulerAngles.y;
        transform.rotation = Quaternion.Euler(0, cameraYaw, 0);
    }

    void LateUpdate()
    {
        if (cameraTransform == null) cameraTransform = Camera.main.transform;

        Vector3 targetPosition = cameraTransform.position + (cameraTransform.forward * distanceFromCamera.z) + (cameraTransform.right * distanceFromCamera.x);
        targetPosition.y = cameraTransform.position.y + distanceFromCamera.y;
        transform.position = Vector3.Lerp(transform.position, targetPosition, Time.deltaTime * followSpeed);

        float cameraYaw = cameraTransform.eulerAngles.y + yRotationOffset;
        Quaternion targetRotation = Quaternion.Euler(0, cameraYaw, 0);
        transform.rotation = Quaternion.Slerp(transform.rotation, targetRotation, Time.deltaTime * followSpeed);
    }
}