using UnityEngine;
using System.Collections;
using QuickTest;
using UnityEngine.SceneManagement;
using Gama_Provider.Simulation;

using UnityEngine.UI;
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
    public Text TextEndEng; 
    public Text TextEndViet;

   
    protected float TimeForDisplayingFloodUI = 2.0f; // in second
    protected float TimerForDisplayingFloodUI = 0.0f;

    protected bool InVietnamese;


    protected bool FloodingPhase = false;
    protected bool FloodingInitPhase = false;


    public bool DikingStart = false;

    public GameObject globalVolume;
    // Use this for initialization
    void Start()
    {
        Instance = this;
    }
    public void Update()
    {
        if (Input.GetKeyDown(KeyCode.Space) && DikingStart)
        {
            APITest.Instance.TestDrawDyke();
        }

        if (Input.GetKeyDown(KeyCode.Space) && UI_ChoiceOfLanguage.active)
        {
            globalVolume.SetActive(true);
            SetInVietnamese(false);
        }
        if (Input.GetKeyDown(KeyCode.Space) && UI_DykingPhase_eng.active)
        {
            globalVolume.SetActive(false);
            StartDikingPhase();
        }
        if (Input.GetKeyDown(KeyCode.Space) && UI_EndingPhase_eng.active)
        {
            globalVolume.SetActive(true);
            RestartGame();
        }
        if (FloodingPhase)
        {
            if (TimerForDisplayingFloodUI > 0)
            {
                globalVolume.SetActive(true);
                TimerForDisplayingFloodUI -= Time.deltaTime;
            }

            if (TimerForDisplayingFloodUI <= 0)
            {
                globalVolume.SetActive(false);
                if (InVietnamese)
                {
                    UI_FloodingPhase_viet.SetActive(false);
                }
                else
                {
                    UI_FloodingPhase_eng.SetActive(false);
                }
               
                if(FloodingInitPhase) {
                    FloodingInitPhase = false;
                    APITest.Instance.TestSetStartPressed();
                } else
                {
                    APITest.Instance.TestSetInFlood();
                    FloodingInitPhase = true;
                } 
                    
                FloodingPhase = false;
            }
        }
       
    }
    public void SetInVietnamese(bool value)
    {
        InVietnamese = value;
        UI_ChoiceOfLanguage.SetActive(false);
        TimerForDisplayingFloodUI = TimeForDisplayingFloodUI;
        FloodingInitPhase = true;
        if (InVietnamese)
        {
            UI_FloodingPhase_viet.SetActive(true);
        } else
        {
            UI_FloodingPhase_eng.SetActive(true);
        }
        FloodingPhase = true;


    }

    public void StartMenuDikingPhase()
    {
        if (InVietnamese)
            UI_DykingPhase_viet.SetActive(true);
        else UI_DykingPhase_eng.SetActive(true);
    }
    public void StartDikingPhase()
    {
        DikingStart = true;
        Debug.Log("StartDikingPhase");
        if (InVietnamese)
            UI_DykingPhase_viet.SetActive(false);
        else UI_DykingPhase_eng.SetActive(false);
        APITest.Instance.TestSetInGame();


    }

    public void StartFloodingPhase()
    {
        DikingStart = false;

        SimulationManager.Instance.DisplayFutureDike = false;
        if (SimulationManager.Instance.FutureDike != null)
        {
            SimulationManager.Instance.FutureDike.SetActive(false);
            GameObject.DestroyImmediate(SimulationManager.Instance.FutureDike);

            SimulationManager.Instance.FutureDike = null;

        }

        TimerForDisplayingFloodUI = TimeForDisplayingFloodUI;
        FloodingPhase = true;
        if (InVietnamese)
        {
            UI_FloodingPhase_viet.SetActive(true);
        }
        else
        {
            UI_FloodingPhase_eng.SetActive(true);
        }


    }

    public void EndGame(int score)
    {

        if (InVietnamese)
        {
            TextEndViet.text = ("" + score + "%");
            UI_EndingPhase_viet.SetActive(true);
        }
        else
        {
            UI_EndingPhase_eng.SetActive(true);
            TextEndEng.text = ("" + score + "%");
        }
    }

    public void RestartGame()
    {
       if (InVietnamese)
            UI_EndingPhase_viet.SetActive(false);
        else UI_EndingPhase_eng.SetActive(false);
        UI_ChoiceOfLanguage.SetActive(true);
    }

}
 