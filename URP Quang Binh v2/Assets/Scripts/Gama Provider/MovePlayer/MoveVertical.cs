using UnityEngine;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.XR;

public class MoveVertical : InputData
{
    public float Speed = 10000.0f;
    public bool RightHand = false;
    public bool UseKeyboard = false;

    public float minY = 0.0f;
    public float maxY = 1500.0f;
    private Transform camTransform;
    public GameObject player;


    public float scrollSensitivity = 1000f;   // Force initiale appliquée selon la molette
    public float damping = 5f;              // Vitesse à laquelle la vitesse s'annule (freinage)
    private float verticalSpeed = 0f;       // Vitesse verticale actuelle


    private void Start()
    {
        camTransform = player.transform;
         
    }
    private void FixedUpdate()
    {
        if (SimulationManager.Instance.IsGameState(GameState.GAME))
            MoveVertically();
        
    }

    private void MoveVertically()
    {
        Vector2 val = new Vector2(0.0f,0.0f) ;
      
        if (UseKeyboard)
        {
            // Entrée molette → ajoute une impulsion de vitesse
            float scrollInput = Input.GetAxis("Mouse ScrollWheel");
            verticalSpeed -= scrollInput * scrollSensitivity;

            // Appliquer déplacement
            Vector3 pos = camTransform.position;
            pos.y += verticalSpeed * Time.deltaTime;
            pos.y = Mathf.Clamp(pos.y, minY, maxY);
            camTransform.position = pos;

            // Appliquer l’inertie (freinage progressif)
            verticalSpeed = Mathf.Lerp(verticalSpeed, 0f, damping * Time.deltaTime);


        }
        else
        {
            InputDevice hand = RightHand ? _rightController : _leftController;
           
            hand.TryGetFeatureValue(CommonUsages.primary2DAxis, out val);
           
            if (val.y != 0.0f)
            {
                camTransform.Translate(Vector3.up * Time.fixedDeltaTime * Speed * val.y);
                Vector3 pos = camTransform.position;
                pos.y = Mathf.Clamp(pos.y, minY, maxY);
                camTransform.position = pos;
            }



        }


    }
}