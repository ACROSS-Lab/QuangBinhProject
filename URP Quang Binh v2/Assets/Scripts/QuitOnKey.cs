using UnityEngine;

public class QuitOnKey : MonoBehaviour
{
    void Update()
    {
        if ((Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.RightControl)
       || Input.GetKey(KeyCode.LeftCommand) || Input.GetKey(KeyCode.RightCommand))
      && Input.GetKeyDown(KeyCode.Escape))
        {
            
            Application.Quit();
        }
    }
}