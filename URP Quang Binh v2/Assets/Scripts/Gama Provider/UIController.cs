using UnityEngine;
 

public abstract class UIController : MonoBehaviour
{
    public GameObject UI_ChoiceOfLanguage;
    public GameObject UI_DykingPhase_eng;
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

    public static UIController Instance = null; 

    public abstract void StartMenuDikingPhase();

    public abstract void StartFloodingPhase();

   
    public abstract void StartDikingPhase(); 

    public abstract void UpdateScore(int scor);

    public abstract void UpdateRound(int round);
    
    public abstract void UpdateLength(bool is_dyke, float length); 
    
}
