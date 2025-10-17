using UnityEngine;
using QuickTest;
using UnityEngine.UI;
using Gama_Provider.Simulation;
using TMPro;

public class UIControllerWithoutVR : UIController
{


  
    public void Update()
    {
        
        if (Input.GetKeyDown(KeyCode.Space) && UI_ChoiceOfLanguage.activeInHierarchy)
        {
            SetInVietnamese(false);
        }
        if (Input.GetKeyDown(KeyCode.Space) && (UI_DykingPhase_last_eng.activeInHierarchy))
        {
            startAfterHint();
        }
        if (Input.GetKeyDown(KeyCode.Space) && (UI_DykingPhase_middle_eng.activeInHierarchy))
        {
            startAfterHint();
        }
        if (Input.GetKeyDown(KeyCode.Space) && (UI_DykingPhase_eng.activeInHierarchy) && ! done)
        {
            StartDikingPhase();
            done = true;
        }
       

        if (Input.GetKeyDown(KeyCode.Space) && UI_EndingPhase_eng.activeInHierarchy)
        {
            RestartGame();
        }
        if (DikingStart && Input.GetKeyDown(KeyCode.K))
        {
            SimulationManager.Instance.ToFloodingPhase();
        }
        if (FloodingPhase)
        {
            if (TimerForDisplayingFloodUI > 0)
            {
                TimerForDisplayingFloodUI -= Time.deltaTime;
                done = false;
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
}