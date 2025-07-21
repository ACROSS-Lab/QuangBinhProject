using UnityEngine;
using QuickTest;
using UnityEngine.UI;
using Gama_Provider.Simulation;
using TMPro;

public class UIControllerWithoutVR : UIController
{
  
   // public GameObject UI_FinalScore;


    public GameObject UI_Info; 
    public GameObject UI_Hint;//, UI_Hint_viet, UI_Hint_eng;
   // public GameObject UI_ScoreRound;
   // public GameObject UI_Length;
    public TextMeshProUGUI score, finalScore, bestScore;
    public TextMeshProUGUI roundTxt;
    public TextMeshProUGUI dykeLength, damLength;
    int round;
    bool isInit = false;
    int bestScoreV = 0;

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
            if (TimerForDisplayingFloodUI > 0)
            {
                TimerForDisplayingFloodUI -= Time.deltaTime;
            }
            else
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

                FloodingPhase = false;
                if (FloodingInitPhase)
                {
                    FloodingInitPhase = false;
                    SimulationManager.Instance.SetStartPressed();
                }
                else
                {
                    SimulationManager.Instance.SetInFlood();
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
        }
        else
        {
            UI_FloodingPhase_eng.SetActive(true);
          
        }

        FloodingPhase = true;
        LogosUI.SetActive(true);
        //Timer_on.SetActive(true);
        //Timer_on.SetActive(false);
        //Timer_off.SetActive(true);
        build_time.SetActive(false);
        flood_time.SetActive(true);

        people_safe_on.SetActive(true);
        people_safe_off.SetActive(false);
       Timer_on.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetNumStep(), false);

    } 

    public override void StartMenuDikingPhase()
    {
        UI_Info.SetActive(false);
        UI_Hint.SetActive(false);
        LogosUI.SetActive(false);
        if (InVietnamese)
            UI_DykingPhase_viet.SetActive(true);
        else UI_DykingPhase_eng.SetActive(true);
        
    }

    public override void StartDikingPhase()
    {
        DikingStart = true;
        Debug.Log("StartDikingPhase");
        if (InVietnamese)
            UI_DykingPhase_viet.SetActive(false);
        else UI_DykingPhase_eng.SetActive(false);
        SimulationManager.Instance.SetInDykeBuilding();
        UI_Info.SetActive(true);
        roundTxt.enabled = true;
        damLength.enabled = true;
        dykeLength.enabled = true;
        if (round > 1)
        {
            score.enabled = true;
        }
        LogosUI.SetActive(true);
        Timer_on.SetActive(true);
        //Timer_off.SetActive(false);
        build_time.SetActive(true);
        flood_time.SetActive(false);
        people_safe_on.SetActive(false); 
        people_safe_off.SetActive(true);

        Timer_on.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetLastTime(), true);
    }

    public override void StartFloodingPhase()
    {
        LogosUI.SetActive(true);
        Timer_on.SetActive(true);
      //  Timer_off.SetActive(true);
        build_time.SetActive(false);
        flood_time.SetActive(true);
        people_safe_on.SetActive(true);
        people_safe_off.SetActive(false);
        DikingStart = false;
        damLength.enabled = false;
        dykeLength.enabled = false;
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
       // Debug.Log("Timer_on: " + Timer_on);

        //Debug.Log(" Timer_on.GetComponentInChildren<CircularProgressBar>(): " + Timer_on.GetComponentInChildren<CircularProgressBar>());
       
        Timer_on.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetNumStep(), false);

    }

    public void EndGame()
    {
        Debug.Log("endthegame");
        LogosUI.SetActive(false);
        UI_Info.SetActive(false);
        UI_Hint.SetActive(false);
       
        if (InVietnamese)
        {
            UI_EndingPhase_viet.SetActive(true);
        }
        else
        {
            UI_EndingPhase_eng.SetActive(true);
        }

        finalScore.text = score.text;
      //  UI_FinalScore.SetActive(true);
        
    }

    public void RestartGame()
    {
        if (InVietnamese)
            UI_EndingPhase_viet.SetActive(false);
        else 
            UI_EndingPhase_eng.SetActive(false);

        UI_Info.SetActive(false);
        UI_Hint.SetActive(false);
        //UI_Hint_viet.SetActive(false);
        //UI_Hint_eng.SetActive(false);
       // UI_FinalScore.SetActive(false);

        UI_ChoiceOfLanguage.SetActive(true);
        score.text = "Last Score: 0";
        dykeLength.text = "Dyke Length: 0m";
        damLength.text = "Dam Length: 0m";
        roundTxt.text = "Round: 1/3";
    }

    public override void UpdateScore(int scor)
    {
        this.score.text = "Last Score:" + scor.ToString();
        if (scor > bestScoreV)
        {
            bestScore.text = "Best Score:" + scor.ToString();
            bestScoreV = scor;
        }
        if(round >= 3) EndGame();
    }

    public override void UpdateRound(int round)
    {
    
        roundTxt.text = "Round: " + round + "/3";
        this.round = round;
        if(round >= 3) UI_Hint.SetActive(true);
    }  

 
    public override void UpdateLength(bool is_dyke, float length)
    {
        if (is_dyke)
        {
            dykeLength.text = "Dyke Length: " + ((int)length).ToString() + "m";


        }
        else
        {
            damLength.text = "Dam Length: " + ((int)length).ToString() + "m";
        }
    }
}