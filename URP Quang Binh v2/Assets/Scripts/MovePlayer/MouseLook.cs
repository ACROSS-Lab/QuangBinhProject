using UnityEngine;


public class MouseLook : MonoBehaviour
{
    public float mouseSensitivity = 100f;
    public Transform playerBody; // Le GameObject du joueur (pivot horizontal)

    float xRotation = 0f;
    public GameObject MouseObj;
    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked; // Bloque le curseur au centre
    }

    void Update()
    {
        
        MouseObj.SetActive(false);
        float mouseX = Input.GetAxis("Mouse X") * mouseSensitivity * Time.deltaTime;
        float mouseY = Input.GetAxis("Mouse Y") * mouseSensitivity * Time.deltaTime;

        xRotation -= mouseY; // Inverser si besoin
        xRotation = Mathf.Clamp(xRotation, -90f, 90f); // Empêche de regarder trop haut/bas

        transform.localRotation = Quaternion.Euler(xRotation, 0f, 0f); // Rotation verticale
        playerBody.Rotate(Vector3.up * mouseX); // Rotation horizontale du corps
        
    }
}