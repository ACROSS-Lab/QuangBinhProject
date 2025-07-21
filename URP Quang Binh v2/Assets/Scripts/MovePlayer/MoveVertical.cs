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


    private void Start()
    {
        if (!UseKeyboard)
            camTransform = Camera.main.transform;
        else
            camTransform = player.transform;
    }
    private void FixedUpdate()
    {
        if (SimulationManager.Instance.IsGameState(GameState.GAME))
            MoveVertically();
    }

    private void MoveVertically()
    {
        Vector2 val;

        if (UseKeyboard)
        {
            float vertical = 0f;

            if (Input.GetKey(KeyCode.P))
            {
                vertical = 1f;
            }
            else if (Input.GetKey(KeyCode.M))
            {
                vertical = -1f;
            }

            val = new Vector2(0, vertical);
        }
        else
        {
            InputDevice hand = RightHand ? _rightController : _leftController;
            hand.TryGetFeatureValue(CommonUsages.primary2DAxis, out val);
           

        }
        camTransform.Translate(Vector3.up * Time.fixedDeltaTime * Speed * val.y);
        Vector3 pos = camTransform.position;
       pos.y = Mathf.Clamp(pos.y, minY, maxY);
        camTransform.position = pos;
    }
}