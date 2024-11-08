using UnityEngine;
using System.Collections;

public class UIController : MonoBehaviour
{

    public static UIController Instance = null;

    protected bool InVietnamese;

    // Use this for initialization
    void Start()
    {
        Instance = this;
    }

    public void SetInVietnamese(bool value)
    {
        Debug.Log("Game in vitenamese:" + value);
	InVietnamese = value;
    }

    public void StartDikingPhase()
    {

    }

    public void RestartGame()
    {

    }

}
