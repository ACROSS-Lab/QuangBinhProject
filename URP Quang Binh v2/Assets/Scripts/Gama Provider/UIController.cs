using UnityEngine;
using TMPro;

using Gama_Provider.Simulation;

public abstract class UIController : MonoBehaviour
{
    public GameObject UI_ChoiceOfLanguage;
    public GameObject UI_DykingPhase_eng;
    public GameObject UI_DykingPhase_last_eng;
    public GameObject UI_FloodingPhase_eng;
    public GameObject UI_EndingPhase_eng;
    public GameObject UI_DykingPhase_viet;
    public GameObject UI_FloodingPhase_viet;
    public GameObject UI_EndingPhase_viet;
    public GameObject LogosUI;
    public GameObject Timer_on; 
    public GameObject Timer_off;
    public GameObject build_time;
    public GameObject flood_time;
    public GameObject people_safe_on;
    public GameObject people_safe_off;
    public int lostPtInjuries, lostPtDam, lostPtDyke, lostPtStakeArea;
    public TextMeshProUGUI score, finalScore, bestScore;
    protected int bestScoreV = 0;
    protected int round;
    public GameObject UI_Info;
    public GameObject UI_Hint;//, UI_Hint_viet, UI_Hint_eng;
                              // public GameObject UI_ScoreRound;
                              // public GameObject UI_Length;
    public TextMeshProUGUI roundTxt;
    public TextMeshProUGUI dykeLength, damLength;
    bool isInit = false;

    protected float TimeForDisplayingFloodUI = 2.0f; // in second
    protected float TimerForDisplayingFloodUI = 0.0f;

    protected bool InVietnamese;


    protected bool FloodingPhase = false;
    protected bool FloodingInitPhase = false;


    public bool DikingStart = false;

    public GameObject globalVolume;
    public TextMeshProUGUI textDyking;

    public static UIController Instance = null;

    // Use this for initialization
    void Start()
    {
        Instance = this;
    }

    public void UpdateScore(int scor, int LPTI, int LPTDa, int LPTDy, int LPTSA)
    {
        lostPtInjuries = LPTI;
        lostPtDam = LPTDa;
        lostPtDyke = LPTDy;
        lostPtStakeArea = LPTSA;
        this.score.text = "Dernier score: " + scor.ToString();
        if (scor > bestScoreV)
        {
            bestScore.text = "Meilleur score: " + scor.ToString();
            bestScoreV = scor;
        }
        if (round >= 3) EndGame();
        

    }



    public void UpdateRound(int round)
    {

        roundTxt.text = "Tour: " + round + "/3";
        this.round = round;

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


    public  void StartMenuDikingPhase()
    {
        UI_Info.SetActive(false);
        UI_Hint.SetActive(false);
        LogosUI.SetActive(false);
            //  public float lostPtInjuries, lostPtDam, lostPtDyke, lostPtStakeArea;
            string t = score.text + "\nPoints perdus à cause des victimes: " + lostPtInjuries + "\nPoints perdus à cause des digues et barrages: " + (lostPtDam + lostPtDyke) + "\nPoints perdus à cause des zones sensibles: " + lostPtStakeArea + "\n";
            if (round >= 3)
                textDyking.SetText(t);
            else textDyking.SetText(t + "\nProtégez la ville en construisant des digues\net des barrages pour faire mieux");
            if (InVietnamese)
                UI_DykingPhase_viet.SetActive(true);
            else UI_DykingPhase_eng.SetActive(true);
        
    }

    public void startDiking()
    {
        DikingStart = true;
        Debug.Log("StartDikingPhase");

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

        Timer_on.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetLastTime(), true);
    }
    public void startAfterHint()
    {
        Debug.Log("startAfterHint");
        UI_Hint.SetActive(true);
        UI_DykingPhase_last_eng.SetActive(false);
        startDiking(); 
    }

    public  void StartDikingPhase()
    {
        flood_time.SetActive(false);
        people_safe_on.SetActive(false);
        people_safe_off.SetActive(true);
        if (InVietnamese)
            UI_DykingPhase_viet.SetActive(false);
        else UI_DykingPhase_eng.SetActive(false);
        Debug.Log("round: " + round);
        if (round >= 3)
        {
            UI_DykingPhase_last_eng.SetActive(true);
        } else
        {
            startDiking();

        }

    }

    public  void StartFloodingPhase()
    {
        LogosUI.SetActive(true);
        Timer_on.SetActive(true);
        //  Timer_off.SetActive(true);
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
        score.text = "Dernier score: 0";
        dykeLength.text = "Longueur de digues: 0m";
        damLength.text = "Longueur de barrages: 0m";
        roundTxt.text = "Tour: 1/3";
    }




    public  void UpdateLength(bool is_dyke, float length)
    {
        if (is_dyke)
        {
            dykeLength.text = "Longueur de digues: " + ((int)length).ToString() + "m";


        }
        else
        {
            damLength.text = "Longueur de barrages: " + ((int)length).ToString() + "m";
        }
    }
}
    

