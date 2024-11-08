using UnityEngine;
using System.Collections;

public class UIController : MonoBehaviour
{

    public static UIController Instance = null;
    public GameObject UI_ChoiceOfLanguage;
    public GameObject UI_DykingPhase_eng;
    public GameObject UI_FloodingPhase_eng;
    public GameObject UI_EndingPhase_eng;
    public GameObject UI_DykingPhase_viet;
    public GameObject UI_FloodingPhase_viet;
    public GameObject UI_EndingPhase_viet;

    protected bool InVietnamese;

    // Use this for initialization
    void Start()
    {
        Instance = this;
    }

    public void SetInVietnamese(bool value)
    {
        InVietnamese = value;
        UI_ChoiceOfLanguage.SetActive(false);
    }

    public void StartDikingPhase()
    {
        if (InVietnamese)
            UI_DykingPhase_viet.SetActive(false);
        else UI_DykingPhase_eng.SetActive(false);
        
    }

    public void RestartGame()
    {
       if (InVietnamese)
            UI_EndingPhase_viet.SetActive(false);
        else UI_EndingPhase_eng.SetActive(false);
    }

}
