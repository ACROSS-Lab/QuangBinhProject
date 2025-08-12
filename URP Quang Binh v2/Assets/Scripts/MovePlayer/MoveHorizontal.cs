using UnityEngine;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.XR;


public class MoveHorizontal : InputData
{
    public bool RightHand = true;

    [SerializeField] private float speed = 10000.0f;
    [SerializeField] private float speedRotation = 10.0f;
    [SerializeField] private bool Strafe = false;
    [SerializeField] private float minX = -450;
    [SerializeField] private float maxX = 2975;
    [SerializeField] private float minZ = -6900;
    [SerializeField] private float maxZ = 250;

    private Transform camTransform;

    // ############################################################

    private void Start()
    {
        camTransform = Camera.main.transform;
    }

    private void FixedUpdate()
    {
        if (SimulationManager.Instance.IsGameState(GameState.GAME))
            MoveHorizontally();
    }

    // ############################################################

    private void MoveHorizontally()
    {
        InputDevice hand = RightHand ? _rightController : _leftController;
        Vector2 val;
        hand.TryGetFeatureValue(CommonUsages.primary2DAxis, out val);

        Vector3 vectF = camTransform.forward;
        vectF.y = 0;
        vectF = Vector3.Normalize(vectF);

        transform.position = transform.position + (vectF * speed * Time.fixedDeltaTime * val.y);
        Vector3 pos = transform.position;
        pos.x = Mathf.Clamp(pos.x, minX, maxX);
        pos.z = Mathf.Clamp(pos.z, minZ, maxZ);
        transform.position = pos;

        // if (Strafe)
        // {
        //     Vector3 vectR = camTransform.right;
        //     vectR.y = 0;
        //     vectR = Vector3.Normalize(vectR);

        //     transform.position += vectR * speed * Time.fixedDeltaTime * val.x;
        // }
        // else
        // {
        //     transform.Rotate(new Vector3(0, 1, 0), Time.fixedDeltaTime * speedRotation * val.x);
        // }
    }
}