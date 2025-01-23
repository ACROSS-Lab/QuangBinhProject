using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;

public class SkipScene : MonoBehaviour
{
    [SerializeField] protected InputActionReference mainButton = null;
    [SerializeField] protected InputActionReference secondButton = null;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (mainButton != null && mainButton.action.triggered && secondButton != null && secondButton.action.triggered || Input.GetKeyDown(KeyCode.Space)) {
            SceneManager.LoadScene("Main Scene - Flood");
        }
    }
}
