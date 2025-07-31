using UnityEngine;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.XR;


public class MoveHorizontal : InputData
{
    public bool RightHand = true;
    public bool UseKeyboard = false;
    public GameObject player;


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
        camTransform = player.transform;
    }

    private void FixedUpdate()
    {
        if (SimulationManager.Instance.IsGameState(GameState.GAME))
            MoveHorizontally();
    }

    // ############################################################

    private void MoveHorizontally()
    {
        Vector2 val;
        if (UseKeyboard)
        {
            float vh = Input.GetAxis("Horizontal");
            float vv = Input.GetAxis("Vertical");
            val = new Vector2(vh, vv);
        }
        else
        {
            InputDevice hand = RightHand ? _rightController : _leftController;
            hand.TryGetFeatureValue(CommonUsages.primary2DAxis, out val);
        }
       
        Vector3 vectF = UseKeyboard ? camTransform.forward : GameObject.FindGameObjectWithTag("MainCamera").transform.forward;
        vectF.y = 0;
        vectF = Vector3.Normalize(vectF);

        camTransform.position = camTransform.position + (vectF * speed * Time.fixedDeltaTime * val.y);
        Vector3 pos = camTransform.position;
        pos.x = Mathf.Clamp(pos.x, minX, maxX);
        pos.z = Mathf.Clamp(pos.z, minZ, maxZ);
        camTransform.position = pos;

        if (Strafe)
        {
            Vector3 vectR = UseKeyboard ? camTransform.right : GameObject.FindGameObjectWithTag("MainCamera").transform.right; 
            vectR.y = 0;
            vectR = Vector3.Normalize(vectR);

            camTransform.position += vectR * speed * Time.fixedDeltaTime * val.x;
        }
        else
        {
            camTransform.Rotate(new Vector3(0, 1, 0), Time.fixedDeltaTime * speedRotation * val.x);
        }
    }
}