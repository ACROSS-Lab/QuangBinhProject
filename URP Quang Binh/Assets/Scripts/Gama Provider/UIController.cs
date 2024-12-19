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

    protected bool InVietnamese = false;


    protected bool FloodingPhase = false;
    protected bool FloodingInitPhase = false;


    public bool DikingStart = false;

    public bool EndOfGame = false;

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
            SetInVietnamese(false);
        }
        if (Input.GetKeyDown(KeyCode.Space) && UI_DykingPhase_eng.active)
        {
            StartDikingPhase();
        }
        if (Input.GetKeyDown(KeyCode.Space) && UI_EndingPhase_eng.active)
        {
            RestartGame();
        }
        if (FloodingPhase)
        {
            Debug.Log("FloodingInitPhase: " + FloodingInitPhase + " globalVolume.activeSelf:" + globalVolume.activeSelf);
            if (FloodingInitPhase && !globalVolume.activeSelf)
                globalVolume.SetActive(true);

            if (TimerForDisplayingFloodUI > 0)
            {
                TimerForDisplayingFloodUI -= Time.deltaTime;
            }

            if (TimerForDisplayingFloodUI <= 0)
            {
                if (InVietnamese)
                {
                    UI_FloodingPhase_viet.SetActive(false);
                }
                else
                {
                    UI_FloodingPhase_eng.SetActive(false);
                }

                FloodingPhase = false;
                if (FloodingInitPhase) {
                    FloodingInitPhase = false;
                    APITest.Instance.TestSetStartPressed();
                } else
                { 
                    APITest.Instance.TestSetInFlood();
                } 
                 
            }
        }
        else
        {
           // globalVolume.SetActive(false);
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
        globalVolume.SetActive(false);

        Debug.Log("StartMenuDikingPhase ");
        Debug.Log("InVietnamese: " + InVietnamese);
        if (InVietnamese)
            UI_DykingPhase_viet.SetActive(true);
        else UI_DykingPhase_eng.SetActive(true);

        Debug.Log("UI_DykingPhase_eng: " + UI_DykingPhase_eng.activeSelf + " UI_DykingPhase_viet:" + UI_DykingPhase_viet.activeSelf);
    }
    public void StartDikingPhase()
    {
        DikingStart = true;
        Debug.Log("StartDikingPhase");
        if (InVietnamese)
            UI_DykingPhase_viet.SetActive(false);
        else UI_DykingPhase_eng.SetActive(false);
        APITest.Instance.TestSetInDykeBuilding();
    }

    public void StartFloodingPhase()
    {
        Debug.Log("StartFloodingPhase");
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

        Debug.Log("END StartFloodingPhase: " + FloodingPhase + "  FloodingInitPhase:" + FloodingInitPhase);

    }

    public void EndGame(ScoreMessage finalResult)
    {
        EndOfGame = finalResult.endgame;
        Debug.Log("Score: " + finalResult.score);
        if (InVietnamese)
        {
            TextEndViet.text = ("Tròn: " + finalResult.round + " Tỷ lệ người được cứu: " + finalResult.score + "%");
            UI_EndingPhase_viet.SetActive(true);
        }
        else
        {
            UI_EndingPhase_eng.SetActive(true);
            TextEndEng.text = ("Round: " + finalResult.round + " Percentage of people saved: " + finalResult.score + "%");
        }
    }

    public void RestartGame()
    {
        Debug.Log("RestartGame - EndOfGame: " + EndOfGame);
       if (InVietnamese)
            UI_EndingPhase_viet.SetActive(false); 
        else UI_EndingPhase_eng.SetActive(false);
        if (EndOfGame)
        {
            UI_ChoiceOfLanguage.SetActive(true);
            EndOfGame = false;
        }
        else
        {
            if (InVietnamese)
            {
                UI_DykingPhase_viet.SetActive(true);
            }
            else
            {
                UI_DykingPhase_eng.SetActive(true);
            }
        }
       
    }

}
 