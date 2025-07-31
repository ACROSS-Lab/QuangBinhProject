using UnityEngine;
using QuickTest;
using UnityEngine.UI;
using Gama_Provider.Simulation;
using TMPro;

public class UIControllerWithVR : UIController
{
  // public TextMeshProUGUI TextEndEng;
    // public TextMeshProUGUI TextEndViet;

   
    public GameObject UI_FinalScore;
    public GameObject UI_HUD;
    public GameObject UI_Hint;//, UI_Hint_viet, UI_Hint_eng; 
    public GameObject UI_ScoreRound_viet, UI_ScoreRound_eng;
    public GameObject UI_Length_viet, UI_Length_eng, UI_Length_data, UI_scoreRound_data;
    public TextMeshProUGUI score, finalScore, bestScore;
    public TextMeshProUGUI roundTxt;
    public TextMeshProUGUI dykeLength, damLength;

    int round;
    bool isInit = false;

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
          //  UI_Hint_viet.SetActive(true);
            UI_ScoreRound_viet.SetActive(true);
            UI_Length_viet.SetActive(true);
        }
        else
        {
            UI_FloodingPhase_eng.SetActive(true);
           // UI_Hint_eng.SetActive(true);
            UI_ScoreRound_eng.SetActive(true);
            UI_Length_eng.SetActive(true);
        }

        UI_Length_data.SetActive(true);
        UI_scoreRound_data.SetActive(true);
        FloodingPhase = true;
        LogosUI.SetActive(true);
        Timer_on.SetActive(false);
        Timer_off.SetActive(true);
        build_time.SetActive(false);
        flood_time.SetActive(true);
        people_safe_on.SetActive(true);
        people_safe_off.SetActive(false);

        flood_time.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetNumStep());

    }

    public override void StartMenuDikingPhase()
    {
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

        LogosUI.SetActive(true);
        Timer_on.SetActive(true);
        Timer_off.SetActive(false);
        build_time.SetActive(true);
        flood_time.SetActive(false);
        people_safe_on.SetActive(false);
        people_safe_off.SetActive(true);
        Timer_on.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetLastTime());
    }

    public override void StartFloodingPhase()
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

        flood_time.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetNumStep());
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

        UI_HUD.SetActive(false);
        UI_Hint.SetActive(false);
        //UI_Hint_viet.SetActive(false);
       // UI_Hint_eng.SetActive(false);
        UI_ScoreRound_viet.SetActive(false);
        UI_ScoreRound_eng.SetActive(false);
        UI_Length_viet.SetActive(false);
        UI_Length_eng.SetActive(false);
        UI_FinalScore.SetActive(false);
        UI_Length_data.SetActive(false);
        UI_scoreRound_data.SetActive(false);


        UI_ChoiceOfLanguage.SetActive(true);
        score.text = "0";
        dykeLength.text = "0";
        damLength.text = "0";
    }

    public override void UpdateScore(int score)
    {
        this.score.text = score.ToString();
        if (score > int.Parse(bestScore.text)) bestScore.text = score.ToString();
        if (round >= 3) EndGame();
    }

    public override void UpdateRound(int round)
    {
        if (!UI_HUD.activeInHierarchy) UI_HUD.SetActive(true);
        roundTxt.text = "" + round;
        this.round = int.Parse(roundTxt.text);
        if (round >= 3) UI_Hint.SetActive(true);
    }

    public override void UpdateLength(bool is_dyke, float length)
    {
        if (is_dyke)
        {
            dykeLength.text = ((int)length).ToString() + "m";
        }
        else
        {
            damLength.text = ((int)length).ToString() + "m";
        }
    }
} 