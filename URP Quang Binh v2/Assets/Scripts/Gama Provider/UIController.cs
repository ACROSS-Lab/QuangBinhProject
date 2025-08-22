using UnityEngine;
using QuickTest;
using UnityEngine.UI;
using Gama_Provider.Simulation;
using TMPro;

public class UIController : MonoBehaviour
{
    public static UIController Instance = null;
    public GameObject UI_DykingPhase;
    public GameObject UI_FloodingPhase;
    public GameObject UI_EndingPhase;
    public GameObject buttonDyke;
    public GameObject textWait;

    public GameObject LogosUI;
    public GameObject Timer_on;
    public GameObject Timer_off;
    public GameObject build_time;
    public GameObject flood_time;
    public GameObject people_safe_on; 
    public GameObject people_safe_off;
    
    public TextMeshProUGUI score, casualties;
    public TextMeshProUGUI roundTxt;
    public Slider resourceSlider;

    protected float TimeForDisplayingFloodUI = 2.0f; // in second
    protected float TimerForDisplayingFloodUI = 0.0f;

    protected bool FloodingPhase = false;
    protected bool FloodingInitPhase = false;


    bool DikingStart = false;

    public GameObject globalVolume;

    // Use this for initialization
    void Start()
    {
        Instance = this;
    }

    public void Update()
    {
        // if (Input.GetKeyDown(KeyCode.Space) && UI_ChoiceOfLanguage.activeInHierarchy)
        // {
        //     SetInGame(false);
        // }

        if (Input.GetKeyDown(KeyCode.Space) && UI_DykingPhase.activeInHierarchy)
        {
            StartDikingPhase();
        }

        if (Input.GetKeyDown(KeyCode.Space) && UI_EndingPhase.activeInHierarchy)
        {
            RestartGame();
        }

        if (FloodingPhase)
        {
            if (TimerForDisplayingFloodUI > 0 && !FloodingInitPhase)
            {
                TimerForDisplayingFloodUI -= Time.deltaTime;
            }
            else
            {
                UI_FloodingPhase.SetActive(false);
                people_safe_on.GetComponent<StatusEffectManager>().StartEnergizedEffect(1000);

                FloodingPhase = false;
                SimulationManager.Instance.SetInFlood();
            }
        }
        else
        {
            // globalVolume.SetActive(false);
        }
    }

    public void SetInGame()
    {
        TimerForDisplayingFloodUI = TimeForDisplayingFloodUI;
        // UI_FloodingPhase.SetActive(true);

        LogosUI.SetActive(true);
        Timer_on.SetActive(false);
        Timer_off.SetActive(true);
        build_time.SetActive(false);
        flood_time.SetActive(true);
        people_safe_on.SetActive(true);
        people_safe_off.SetActive(false);

        SimulationManager.Instance.SetStartPressed();
        flood_time.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetNumStep());

    }

    public void StartMenuDikingPhase()
    {
        // LogosUI.SetActive(false);
        UI_DykingPhase.SetActive(true);
        buttonDyke.SetActive(true);
        textWait.SetActive(false);
    }

    public void StartDikingPhase()
    {
        // DikingStart = true;
        // UI_DykingPhase.SetActive(false);
        buttonDyke.SetActive(false);
        textWait.SetActive(true); 
        SimulationManager.Instance.SetInDykeBuilding();
        resourceSlider.gameObject.SetActive(true);
        resourceSlider.value = 1.0f; // Reset resource slider to full
        
    }

    public void StartToBuildDyke()
    {
        if (!DikingStart)
        {
            UI_DykingPhase.SetActive(false);

            LogosUI.SetActive(true);
            Timer_on.SetActive(true);
            Timer_off.SetActive(false);
            build_time.SetActive(true);
            flood_time.SetActive(false);
            people_safe_on.SetActive(false);
            people_safe_off.SetActive(true);
            Timer_on.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetLastTime());
            
            DikingStart = true;
        }
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
            DestroyImmediate(SimulationManager.Instance.FutureDike);
            SimulationManager.Instance.FutureDike = null;
        }

        TimerForDisplayingFloodUI = TimeForDisplayingFloodUI;
        FloodingPhase = true;
        UI_FloodingPhase.SetActive(true);
        resourceSlider.gameObject.SetActive(false);

        flood_time.GetComponent<StatusEffectManager>().StartEnergizedEffect(SimulationManager.Instance.GetNumStep());
    }

    public void EndFlooding(int score, int casualties)
    {
        LogosUI.SetActive(false);
        UI_EndingPhase.SetActive(true);
        this.score.text = score.ToString();
        this.casualties.text = casualties.ToString(); 
    }

    public void RestartGame()
    {
        UI_EndingPhase.SetActive(false);
        SimulationManager.Instance.newPhase = true;
    }
}