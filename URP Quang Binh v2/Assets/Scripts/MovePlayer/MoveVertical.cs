using UnityEngine;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.XR;

public class MoveVertical : InputData
{
    public float Speed = 10000.0f;
    public bool RightHand = false;

    public float minY = 0.0f;
    public float maxY = 1500.0f;


    private void FixedUpdate()
    {
        if (SimulationManager.Instance.IsGameState(GameState.GAME))
            MoveVertically();
    }

    private void MoveVertically()
    {
        InputDevice hand = RightHand ? _rightController : _leftController;
        Vector2 val;
        hand.TryGetFeatureValue(CommonUsages.primary2DAxis, out val);
        transform.Translate(Vector3.up * Time.fixedDeltaTime * Speed * val.y);
        Vector3 pos = transform.position;
        pos.y = Mathf.Clamp(pos.y, minY, maxY);
        transform.position = pos;
    }
}