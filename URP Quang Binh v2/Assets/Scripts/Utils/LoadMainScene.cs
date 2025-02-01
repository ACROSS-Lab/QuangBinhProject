using UnityEngine;
using UnityEngine.SceneManagement;

namespace QuickTest
{
    public class LoadMainScene : MonoBehaviour
    {
        public void LoadScene()
        {
            SceneManager.LoadScene("Main Scene - Flood");
        }
    }
}