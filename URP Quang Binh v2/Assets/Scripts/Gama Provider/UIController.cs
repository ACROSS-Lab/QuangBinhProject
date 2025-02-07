using UnityEngine;
using QuickTest;
using UnityEngine.UI;
using Gama_Provider.Simulation;
using TMPro;

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
    // public TextMeshProUGUI TextEndEng;
    // public TextMeshProUGUI TextEndViet;

    public GameObject LogosUI;
    public GameObject Timer_on;
    public GameObject Timer_off;
    public GameObject build_time;
    public GameObject flood_time;
    public GameObject people_safe_on; 
    public GameObject people_safe_off;

    public GameObject UI_FinalScore;
    public GameObject UI_HUD;
    public GameObject UI_Hint, UI_Hint_viet, UI_Hint_eng;
    public GameObject UI_ScoreRound_viet, UI_ScoreRound_eng;
    public GameObject UI_Length_viet, UI_Length_eng;
    public TextMeshProUGUI score, finalScore, bestScore;
    public TextMeshProUGUI roundTxt;
    public TextMeshProUGUI dykeLength, damLength;

    int round;

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
       
        if (Input.GetKeyDown(KeyCode.Space) && UI_ChoiceOfLanguage.activeInHierarchy)
        {
            SetInVietnamese(false);
        }

        if (Input.GetKeyDown(KeyCode.Space) && UI_DykingPhase_eng.activeInHierarchy)
        {
            StartDikingPhase();
        }

        if (Input.GetKeyDown(KeyCode.Space) && UI_EndingPhase_eng.activeInHierarchy)
        {
            RestartGame();
        }

        if (FloodingPhase)
        {
          //  globalVolume.SetActive(true);
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
                people_safe_on.GetComponent<StatusEffectManager>().StartEnergizedEffect(1000);

                if (FloodingInitPhase)
                {
                    FloodingInitPhase = false;
                    SimulationManager.Instance.SetStartPressed();
                }
                else
                {
                    SimulationManager.Instance.SetInFlood();
                   // FloodingInitPhase = true;
                }

                FloodingPhase = false;
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
            UI_Hint_viet.SetActive(true);
            UI_ScoreRound_viet.SetActive(true);
            UI_Length_viet.SetActive(true);
        }
        else
        {
            UI_FloodingPhase_eng.SetActive(true);
            UI_Hint_eng.SetActive(true);
            UI_ScoreRound_eng.SetActive(true);
            UI_Length_eng.SetActive(true);
        }

        FloodingPhase = true;
        LogosUI.SetActive(true);
        Timer_on.SetActive(false);
        Timer_off.SetActive(true);
        build_time.SetActive(false);
        flood_time.SetActive(true);
        people_safe_on.SetActive(true);
        people_safe_off.SetActive(false);

} 

public void StartMenuDikingPhase()
    {
        LogosUI.SetActive(false);
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
        SimulationManager.Instance.SetInDykeBuilding();

        LogosUI.SetActive(true);
        Timer_on.SetActive(true);
        Timer_off.SetActive(false);
        build_time.SetActive(true);
        flood_time.SetActive(false);
        people_safe_on.SetActive(false); 
        people_safe_off.SetActive(true);
        Timer_on.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetLastTime());
    }

    public void StartFloodingPhase()
    {
        LogosUI.SetActive(true);
        Timer_on.SetActive(false);
        Timer_off.SetActive(true);
        build_time.SetActive(false);
        flood_time.SetActive(true);
        people_safe_on.SetActive(true);
        people_safe_off.SetActive(false);
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

    public void EndGame()
    {
        Debug.Log("endthegame");
        LogosUI.SetActive(false);
       
        if (InVietnamese)
        {
            UI_EndingPhase_viet.SetActive(true);
        }
        else
        {
            UI_EndingPhase_eng.SetActive(true);
        }

        finalScore.text = score.text;
        UI_FinalScore.SetActive(true);
        
    }

    public void RestartGame()
    {
        if (InVietnamese)
            UI_EndingPhase_viet.SetActive(false);
        else 
            UI_EndingPhase_eng.SetActive(false);

        UI_FinalScore.SetActive(false);
        UI_ChoiceOfLanguage.SetActive(true);
    }

    public void UpdateScore(int score)
    {
        this.score.text = score.ToString();
        if(score > int.Parse(bestScore.text)) bestScore.text = score.ToString();
        if(round >= 3) EndGame();
    }

    public void UpdateRound(int round)
    {
        if(!UI_HUD.activeInHierarchy) UI_HUD.SetActive(true);
        roundTxt.text = "" + round;
        this.round = int.Parse(roundTxt.text);
        if(round >= 3) UI_Hint.SetActive(true);
    }

    public void UpdateLength(TextMeshProUGUI text, float length)
    {
        text.text = length.ToString() + "m";
    }
}