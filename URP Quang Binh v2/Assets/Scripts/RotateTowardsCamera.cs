using UnityEngine;

public class RotateTowardsCamera : MonoBehaviour
{
    [SerializeField] private Transform camTransform;

    void Start()
    {
        // Si aucune caméra n'est assignée dans l’inspecteur, on prend la MainCamera
        if (camTransform == null && Camera.main != null)
            camTransform = Camera.main.transform;
    }

    void Update()
    {
        if (camTransform == null) return;

        // Calcul direction sans inclinaison verticale
        Vector3 directionToCamera = camTransform.position - transform.position;
        directionToCamera.y = 0;

        if (directionToCamera.sqrMagnitude > 0.0001f)
        {
            Quaternion targetRotation = Quaternion.LookRotation(directionToCamera);
            transform.rotation = targetRotation;
        }
    }
}
