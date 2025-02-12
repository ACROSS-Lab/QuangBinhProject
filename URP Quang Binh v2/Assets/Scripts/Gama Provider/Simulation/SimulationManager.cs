using System;
using System.Collections;
using System.Collections.Generic;
using Gama_Provider.Simulation;
using QuickTest;
using TMPro;
using UnityEngine;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.InputSystem;
using UnityEngine.XR.Interaction.Toolkit.Interactors;


public class SimulationManager : MonoBehaviour
{
    [SerializeField] protected InputActionReference primaryRightHandButton = null;
    [SerializeField] protected InputActionReference rightHandTriggerButton = null;
    [SerializeField] protected XRRayInteractor leftXRRayInteractor;
    [SerializeField] protected XRRayInteractor rightXRRayInteractor;


    [Header("Base GameObjects")] [SerializeField]
    protected GameObject player;

    [SerializeField] protected GameObject Ground;


    // optional: define a scale between GAMA and Unity for the location given
    [Header("Coordinate conversion parameters")]
    protected float GamaCRSCoefX = 1.0f;

    protected float GamaCRSCoefY = 1.0f;
    protected float GamaCRSOffsetX = 0.0f;
    protected float GamaCRSOffsetY = 0.0f;


    protected Transform XROrigin;

    // Z offset and scale
    protected float GamaCRSOffsetZ = 0.0f;

    protected List<GameObject> toFollow;

    XRInteractionManager interactionManager;

    // ################################ EVENTS ################################
    // called when the current game state changes
    public static event Action<GameState> OnGameStateChanged;

    // called when the game is restarted
    public static event Action OnGameRestarted;


    // called when the world data is received
    // public static event Action<WorldJSONInfo> OnWorldDataReceived;
    // ########################################################################

    protected Dictionary<string, List<object>> geometryMap;
    protected Dictionary<string, PropertiesGAMA> propertyMap = null;
    protected List<GameObject> SelectedObjects;

    protected bool handleGeometriesRequested;
    protected bool handleGroundParametersRequested;

    protected CoordinateConverter converter = null;
    protected PolygonGenerator polyGen = null;
    protected ConnectionParameter parameters = null;
    protected AllProperties propertiesGAMA = null;
    protected WorldJSONInfo infoWorld = null;
    protected AnimationInfo infoAnimation = null;
    protected GameState currentState;

    public static SimulationManager Instance = null;

    // allows to define the minimal time bewteen two interactions
    protected float timeWithoutInteraction = 1.0f; //in second

    protected float remainingTime = 0.0f;


    protected bool sendMessageToReactivatePositionSent = false;

    protected float maxTimePing = 1.0f;
    protected float currentTimePing = 0.0f;

    protected List<GameObject> toDelete;

    protected bool readyToSendPosition = false;

    protected bool readyToSendPositionInit = true;

    protected float TimeSendPosition = 0.05f;
    protected float TimeSendPositionAfterMoving = 1.0f;
    protected float TimerSendPosition = 0.0f;

    protected List<GameObject> locomotion;
    protected MoveHorizontal mh = null;
    protected MoveVertical mv = null;

    protected DEMData data;
    protected DEMDataLoc dataLoc;
    protected TeleportAreaInfo dataTeleport;
    protected WallInfo dataWall;
    protected EnableMoveInfo enableMove;

    protected float TimeSendInit = 0.5f;
    protected float TimerSendInit;

  //  protected Coroutine activeCoroutine = null;

    protected Vector3 StartPoint;
    protected Vector3 EndPoint;

    protected GameObject startPoint;
    protected GameObject endPoint;

    protected ScoreMessage scoreM;
    protected RoundMessage roundM;
    protected DykeLengthMessage dykeM;
    protected DamLengthMessage damM;

    protected Vector3 originalStartPosition;
    protected bool firstPositionStored;

    protected Boolean StartMenuDone = false;
    private string _currentStage = "s_start";

    private bool _inTriggerPress = false;

    public GameObject FutureDike = null;
    protected PropertiesGAMA propFutureDike;
    public bool DisplayFutureDike = false;
    protected bool StartFloodingDone = false;

    [SerializeField] protected GameObject FinalScene;
    [SerializeField] protected GameObject WinAnimtion;
    [SerializeField] protected GameObject LooseAnimtion;

    [SerializeField] protected InputActionReference mainButton = null;
    [SerializeField] protected InputActionReference secondButton = null;

    //[SerializeField] protected GameObject tutorial;

    [SerializeField] protected StatusEffectManager timer;
    [SerializeField] protected StatusEffectManager safeRateCount;
    [SerializeField] private TextMeshProUGUI timerText;

    protected float LastTime;
    protected float RemainingSeconds;

    // ############################################ UNITY FUNCTIONS ############################################
    void Awake()
    {
        Instance = this;
        SelectedObjects = new List<GameObject>();
        // toDelete = new List<GameObject>();

        startPoint = GameObject.FindGameObjectWithTag("startPoint");
        endPoint = GameObject.FindGameObjectWithTag("endPoint");

        if (endPoint != null)
            endPoint.SetActive(false);
        if (startPoint != null)
            startPoint.SetActive(false);

        propFutureDike = new PropertiesGAMA
        {
            red = 0,
            blue = 0,
            green = 255,
            hasCollider = false,
            hasPrefab = false,
            height = 40 * 10000,
            is3D = true,
            visible = true
        };


        XROrigin = player.transform.Find("XR Origin (XR Rig)");
        timer.gameObject.SetActive(false);
    }

    void StartTheFlood()
    {
        //StartTime = Time.time;
        //startButton.gameObject.SetActive(false);
    }

    public float GetLastTime()
    {
        return LastTime;
    }
    void OnEnable()
    {
        if (ConnectionManager.Instance != null)
        {
            ConnectionManager.Instance.OnServerMessageReceived += HandleServerMessageReceived;
            ConnectionManager.Instance.OnConnectionAttempted += HandleConnectionAttempted;
            ConnectionManager.Instance.OnConnectionStateChanged += HandleConnectionStateChanged;
            Debug.Log("SimulationManager: OnEnable");
        }
        else
        {
            Debug.Log("No connection manager");
        }
    }

    void OnDisable()
    {
        Debug.Log("SimulationManager: OnDisable");
        ConnectionManager.Instance.OnServerMessageReceived -= HandleServerMessageReceived;
        ConnectionManager.Instance.OnConnectionAttempted -= HandleConnectionAttempted;
        ConnectionManager.Instance.OnConnectionStateChanged -= HandleConnectionStateChanged;
    }

    void OnDestroy()
    {
        Debug.Log("SimulationManager: OnDestroy");
    }

    void Start()
    {
        geometryMap = new Dictionary<string, List<object>>();
        handleGeometriesRequested = false;
        // handlePlayerParametersRequested = false;
        handleGroundParametersRequested = false;
        infoWorld = null;
        //interactionManager = player.GetComponentInChildren<XRInteractionManager>();
        OnEnable();
    }


    void FixedUpdate()
    {
        if (sendMessageToReactivatePositionSent)
        {
            Dictionary<string, string> args = new Dictionary<string, string>
            {
                {
                    "id",
                    ConnectionManager.Instance.getUseMiddleware()
                        ? ConnectionManager.Instance.GetConnectionId()
                        : ("\"" + ConnectionManager.Instance.GetConnectionId() + "\"")
                }
            };

            ConnectionManager.Instance.SendExecutableAsk("player_position_updated", args);
            sendMessageToReactivatePositionSent = false;
        }

        if (handleGroundParametersRequested)
        {
            InitGroundParameters();
            handleGroundParametersRequested = false;
        }

        if (handleGeometriesRequested && infoWorld != null && infoWorld.isInit)
        {
            sendMessageToReactivatePositionSent = true;
            GenerateGeometries(true, new List<string>());
            handleGeometriesRequested = false;
            UpdateGameState(GameState.GAME);
        }

        if (infoWorld != null && !infoWorld.isInit && IsGameState(GameState.LOADING_DATA))
        {
            infoWorld = null;
        }

        if (converter != null && data != null)
        {
            //manageUpdateTerrain();
        }

        if (converter != null && dataLoc != null)
        {
            //manageSetValueTerrain();
        }

        if (converter != null && dataTeleport != null)
        {
            //manageTeleportationArea();
        }

        if (converter != null && dataWall != null)
        {
            //manageWalls();
        }

        if (enableMove != null)
        {
            //playerMovement(enableMove.enableMove);
            //enableMove = null;
        }

        if (infoAnimation != null)
        {
            //updateAnimation();
            //infoAnimation = null;
        }

        if (IsGameState(GameState.LOADING_DATA) && ConnectionManager.Instance.getUseMiddleware())
        {
            if (TimerSendInit > 0)
                TimerSendInit -= Time.deltaTime;
            if (TimerSendInit <= 0)
            {
                TimerSendInit = TimeSendInit;
                Dictionary<string, string> args = new Dictionary<string, string>
                {
                    { "id", ConnectionManager.Instance.GetConnectionId() }
                };
                ConnectionManager.Instance.SendExecutableAsk("send_init_data", args);
            }
        }

        if (IsGameState(GameState.GAME))
        {
            if (readyToSendPosition && TimerSendPosition <= 0.0f)
                UpdatePlayerPosition();
            if (infoWorld != null && !infoWorld.isInit)
                UpdateAgentsList();
        }
    }

    void UpdateGame()
    {
        if (IsGameState(GameState.GAME) && infoWorld != null)
        {
            if (_currentStage != infoWorld.state)
            {
                Debug.Log("BEGIN OF STAGE : " + infoWorld.state);
                _currentStage = infoWorld.state;
                if (_currentStage == "s_diking")
                {
                    if (!StartMenuDone )
                    {
                        UIController.Instance.StartMenuDikingPhase();
                        StartMenuDone = true;
                        StartFloodingDone = false;
                    }
                }
            }

            if (infoWorld.state == "wait_flooding")
            {
                if (!StartFloodingDone)
                {
                    StartMenuDone = false;
                    UIController.Instance.StartFloodingPhase();
                    if (FutureDike != null)
                    {
                        FutureDike.SetActive(false);
                        GameObject.DestroyImmediate(FutureDike);

                        FutureDike = null;
                    }

                    DisplayFutureDike = false;
                    Debug.Log("Display future dike is false at wait flooding");
                    StartFloodingDone = true;
                }
            }

            if (infoWorld.state == "s_init")
            {
                Debug.Log("infoWorld.casualties: " + infoWorld.casualties + " UIController.Instance.people_safe_on.activeSelf:" + UIController.Instance.people_safe_on.activeSelf);
                if (UIController.Instance.people_safe_on.activeSelf)
                {
                    UIController.Instance.people_safe_on.GetComponent<StatusEffectManager>().UpdateEnergizedEffect(1000 - infoWorld.casualties);
                } 
            }
            else if (infoWorld.state == "s_diking")
            {
                //timeText.text = "Remaining Time: " + Math.Max(0, infoWorld.remaining_time); 
            } 
            else if (infoWorld.state == "s_flooding")
            {
                if (UIController.Instance.people_safe_on.activeSelf)
                {
                    UIController.Instance.people_safe_on.GetComponent<StatusEffectManager>().UpdateEnergizedEffect(1000 - infoWorld.casualties);
                }
            }

            if (infoWorld.state != "s_init" && infoWorld.remaining_time > LastTime)
            {
                //Debug.Log("Remaining time: " + infoWorld.remaining_time);
               // timer.StartEnergizedEffect(infoWorld.remaining_time);
                RemainingSeconds = infoWorld.remaining_time;
                //TimeSpan timeSpan = TimeSpan.FromSeconds(RemainingSeconds);
                //timerText.text = timeSpan.ToString(@"mm\:ss");
              //  if (activeCoroutine != null)
               //     StopCoroutine(activeCoroutine);
                timerText.gameObject.SetActive(true);
                //activeCoroutine = StartCoroutine(CountdownCoroutine());
            }

            if (infoWorld.state == "s_init" || UIController.Instance.UI_EndingPhase_eng.activeSelf ||
                UIController.Instance.UI_EndingPhase_viet.activeSelf)
            {
                timer.gameObject.SetActive(false);
                timerText.gameObject.SetActive(false);
            }

            LastTime = infoWorld.remaining_time;

            //RemainingSeconds -= Time.unscaledDeltaTime;
            //TimeSpan timeSpan = TimeSpan.FromSeconds(Math.Max(0, RemainingSeconds));
            Debug.Log("Remaining time span: " + Math.Max(0, (int)LastTime));
            //timerText.text = timeSpan.ToString(@"mm\:ss");

            //TimeSpan timeSpan = TimeSpan.FromSeconds(RemainingSeconds);
            //timerText.text = timeSpan.ToString(@"mm\:ss");
        }
    }

    public void SetInDykeBuilding()
    {
        Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.IN_DYKE_BUILDING.ToString() }
            };

        ConnectionManager.Instance.SendExecutableAsk("set_status", args);
    }

    public void SetStartPressed()
    {
        Debug.Log("SetStartPressed");
        Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.START_PRESSED.ToString() }
            };

        ConnectionManager.Instance.SendExecutableAsk("set_status", args);
    }

    public void SetInFlood()
    {
        Debug.Log("SetInFlood");
        Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.IN_FLOOD.ToString() }
            };

        ConnectionManager.Instance.SendExecutableAsk("set_status", args);
    }

    private IEnumerator CountdownCoroutine()
    {
        do
        {
            TimeSpan timeSpan = TimeSpan.FromSeconds(RemainingSeconds);
            timerText.text = timeSpan.ToString(@"mm\:ss");
            yield return new WaitForSecondsRealtime(1f); // Wait for 1 second, unaffected by time scale
            RemainingSeconds--; // Decrease time
        } while (RemainingSeconds >= 0);

        RemainingSeconds = 0;
        yield return null;
    }

    private void Update()
    {
        if (remainingTime > 0)
            remainingTime -= Time.deltaTime;
        if (TimerSendPosition > 0)
        {
            TimerSendPosition -= Time.deltaTime;
        }

        if (currentTimePing > 0)
        {
            currentTimePing -= Time.deltaTime;
            if (currentTimePing <= 0)
            {
                Debug.Log("Try to reconnect to the server");
                ConnectionManager.Instance.Reconnect();
            }
        }

        if (mainButton != null && secondButton != null && mainButton.action.triggered && secondButton.action.triggered && _currentStage == "s_diking")
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() }
            };

            ConnectionManager.Instance.SendExecutableAsk("end_diking", args);
        }

        

        // Debug.Log("currentStage: " + currentStage + " IsGameState(GameState.GAME) :" +IsGameState(GameState.GAME));
        if (IsGameState(GameState.GAME) && UIController.Instance.DikingStart)
            ProcessRightHandTrigger();

        //UpdateTimeLeftToBuildDykes();
        OtherUpdate();
        UpdateGame();
        if (scoreM != null)
        {
            UIController.Instance.UpdateScore(scoreM.score);
            scoreM = null;
        }
        if(roundM != null)
        {
            UIController.Instance.UpdateRound(roundM.round);
            roundM = null;
        }
        if(dykeM != null)
        {
            UIController.Instance.UpdateLength(UIController.Instance.dykeLength, dykeM.dykeLength);
            dykeM = null;
        }
        if(damM != null)
        {
            UIController.Instance.UpdateLength(UIController.Instance.damLength, damM.damLength);
            damM = null;
        }
    }


    void GenerateGeometries(bool initGame, List<string> toRemove)
    {
        if (infoWorld.position != null && infoWorld.position.Count > 1 &&
            (initGame || !sendMessageToReactivatePositionSent))
        {
            Vector3 pos = converter.fromGAMACRS(infoWorld.position[0], infoWorld.position[1], infoWorld.position[2]);
            XROrigin.localPosition = pos;
            //Camera.main.transform.position = pos;

            // Debug.Log("player.transform.position: " + pos[0] + "," + pos[1] + "," + pos[2]);
            sendMessageToReactivatePositionSent = true;
            readyToSendPosition = true;
            TimerSendPosition = TimeSendPositionAfterMoving;
        }

        foreach (string n in infoWorld.keepNames)
            toRemove.Remove(n);
        int cptPrefab = 0;
        int cptGeom = 0;
        for (int i = 0; i < infoWorld.names.Count; i++)
        {
            string name = infoWorld.names[i];
            string propId = infoWorld.propertyID[i];

            PropertiesGAMA prop = propertyMap[propId];
            GameObject obj = null;

            if (prop.hasPrefab)
            {
                if (initGame || !geometryMap.ContainsKey(name))
                {
                    obj = instantiatePrefab(name, prop, initGame);
                }
                else
                {
                    List<object> o = geometryMap[name];
                    GameObject obj2 = (GameObject)o[0];
                    PropertiesGAMA p = (PropertiesGAMA)o[1];
                    if (p == prop)
                    {
                        obj = obj2;
                    }
                    else
                    {
                        obj2.transform.position = new Vector3(0, -100, 0);
                        geometryMap.Remove(name);
                        if (toFollow != null && toFollow.Contains(obj2))
                            toFollow.Remove(obj2);

                        GameObject.Destroy(obj2);
                        obj = instantiatePrefab(name, prop, initGame);
                    }
                }

                List<int> pt = infoWorld.pointsLoc[cptPrefab].c;
                Vector3 pos = converter.fromGAMACRS(pt[0], pt[1], pt[2]);
                pos.y += pos.y + prop.yOffsetF;
                float rot = prop.rotationCoeffF * ((0.0f + pt[3]) / parameters.precision) + prop.rotationOffsetF;

                if (infoWorld.attributes != null && infoWorld.attributes.Count > 0)
                {
                    float length = infoWorld.attributes[i].length;
                    float rotation = infoWorld.attributes[i].rotation;
                    if(length > 0)
                    {
                        obj.transform.localScale = new Vector3(obj.transform.localScale.x, obj.transform.localScale.y, length);
                        rot = rotation;
                    }
                }

                obj.transform.SetPositionAndRotation(pos, Quaternion.AngleAxis(rot, Vector3.up));
                //obj.SetActive(true);
                toRemove.Remove(name);
                cptPrefab++;
            }
            else
            {
                if (polyGen == null)
                {
                    polyGen = PolygonGenerator.GetInstance();
                    polyGen.Init(converter);
                }

                List<int> pt = infoWorld.pointsGeom[cptGeom].c;
                float yOffset = (0.0f + infoWorld.offsetYGeom[cptGeom]) / (0.0f + parameters.precision);

                obj = polyGen.GeneratePolygons(false, name, pt, prop, parameters.precision);
                obj.transform.position = new Vector3(obj.transform.position.x, obj.transform.position.y + yOffset,
                    obj.transform.position.z);

                if (prop.hasCollider)
                {
                    MeshCollider mc = obj.AddComponent<MeshCollider>();
                    if (prop.isGrabable)
                    {
                        mc.convex = true;
                    }

                    mc.sharedMesh = polyGen.surroundMesh;
                    // mc.isTrigger = prop.isTrigger;
                }

                instantiateGO(obj, name, prop);
                // polyGen.surroundMesh = null;

                if (geometryMap.ContainsKey(name))
                {
                    GameObject objOld = (GameObject)geometryMap[name][0];
                    // objOld.transform.position = new Vector3(0, -100, 0);
                    geometryMap.Remove(name);
                    GameObject.Destroy(objOld);
                }

                List<object> pL = new List<object>();
                pL.Add(obj);
                pL.Add(prop);
                toRemove.Remove(name);

                if (!initGame)
                {
                    geometryMap.Add(name, pL);
                }

                //obj.SetActive(true);
                cptGeom++;
            }
        }

        infoWorld = null;
    }


    // ############################################ GAMESTATE UPDATER ############################################
    public void UpdateGameState(GameState newState)
    {
        switch (newState)
        {
            case GameState.MENU:
                Debug.Log("SimulationManager: UpdateGameState -> MENU");
                break;

            case GameState.WAITING:
                Debug.Log("SimulationManager: UpdateGameState -> WAITING");
                break;

            case GameState.LOADING_DATA:
                Debug.Log("SimulationManager: UpdateGameState -> LOADING_DATA");
                if (ConnectionManager.Instance.getUseMiddleware())
                {
                    Dictionary<string, string> args = new Dictionary<string, string>
                    {
                        { "id", ConnectionManager.Instance.GetConnectionId() }
                    };
                    ConnectionManager.Instance.SendExecutableAsk("send_init_data", args);
                }

                TimerSendInit = TimeSendInit;
                break;

            case GameState.GAME:
                Debug.Log("SimulationManager: UpdateGameState -> GAME");
                if (ConnectionManager.Instance.getUseMiddleware())
                {
                    Dictionary<string, string> args = new Dictionary<string, string>
                    {
                        { "id", ConnectionManager.Instance.GetConnectionId() }
                    };
                    ConnectionManager.Instance.SendExecutableAsk("player_ready_to_receive_geometries", args);
                }

                break;

            case GameState.END:
                Debug.Log("SimulationManager: UpdateGameState -> END");
                break;

            case GameState.CRASH:
                Debug.Log("SimulationManager: UpdateGameState -> CRASH");
                break;

            default:
                Debug.Log("SimulationManager: UpdateGameState -> UNKNOWN");
                break;
        }

        currentState = newState;
        OnGameStateChanged?.Invoke(currentState);
    }


    // ############################# INITIALIZERS ####################################


    private void InitGroundParameters()
    {
        Debug.Log("GroundParameters : Beginnig ground initialization");
        if (Ground == null)
        {
            Debug.LogError("SimulationManager: Ground not set");
            return;
        }

        Vector3 ls = converter.fromGAMACRS(parameters.world[0], parameters.world[1], 0);

        if (ls.z < 0)
            ls.z = -ls.z;
        if (ls.x < 0)
            ls.x = -ls.x;
        ls.y = Ground.transform.localScale.y;

        Ground.transform.localScale = ls;
        Vector3 ps = converter.fromGAMACRS(parameters.world[0] / 2, parameters.world[1] / 2, 0);

        Ground.transform.position = ps;
        Debug.Log("SimulationManager: Ground parameters initialized");
    }


    // ############################################ UPDATERS ############################################
    private void UpdatePlayerPosition()
    {
        Vector2 vF = new Vector2(Camera.main.transform.forward.x, Camera.main.transform.forward.z);
        Vector2 vR = new Vector2(transform.forward.x, transform.forward.z);
        vF.Normalize();
        vR.Normalize();
        float c = vF.x * vR.x + vF.y * vR.y;
        float s = vF.x * vR.y - vF.y * vR.x;
        int angle = (int)(((s > 0) ? -1.0 : 1.0) * (180 / Math.PI) * Math.Acos(c) * parameters.precision);

        //List<int> p = converter.toGAMACRS3D(player.transform.position);

        Vector3 v = new Vector3(Camera.main.transform.position.x, player.transform.position.y,
            Camera.main.transform.position.z);

        if (!firstPositionStored)
        {
            originalStartPosition = v;
            firstPositionStored = true;
        }

        List<int> p = converter.toGAMACRS3D(v);
        Dictionary<string, string> args = new Dictionary<string, string>
        {
            {
                "id",
                ConnectionManager.Instance.getUseMiddleware()
                    ? ConnectionManager.Instance.GetConnectionId()
                    : ("\"" + ConnectionManager.Instance.GetConnectionId() + "\"")
            },
            { "x", "" + p[0] },
            { "y", "" + p[1] },
            { "z", "" + p[2] },
            { "angle", "" + angle }
        };

        ConnectionManager.Instance.SendExecutableAsk("move_player_external", args);

        TimerSendPosition = TimeSendPosition;
    }


    private void instantiateGO(GameObject obj, String name, PropertiesGAMA prop)
    {
        obj.name = name;
        if (prop.toFollow)
        {
            toFollow.Add(obj);
        }

        if (prop.tag != null && !string.IsNullOrEmpty(prop.tag))
            obj.tag = prop.tag;

        if (prop.isInteractable)
        {
            if (interactionManager == null)
                interactionManager = GameObject.FindFirstObjectByType<XRInteractionManager>();

            UnityEngine.XR.Interaction.Toolkit.Interactables.XRBaseInteractable interaction = null;
            if (prop.isGrabable)
            {
                interaction = obj.AddComponent<UnityEngine.XR.Interaction.Toolkit.Interactables.XRGrabInteractable>();
                Rigidbody rb = obj.GetComponent<Rigidbody>();
                if (prop.constraints != null && prop.constraints.Count == 6)
                {
                    if (prop.constraints[0])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezePositionX;
                    if (prop.constraints[1])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezePositionY;
                    if (prop.constraints[2])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezePositionZ;
                    if (prop.constraints[3])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezeRotationX;
                    if (prop.constraints[4])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezeRotationY;
                    if (prop.constraints[5])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezeRotationZ;
                }
            }
            else
            {
                interaction = obj.AddComponent<UnityEngine.XR.Interaction.Toolkit.Interactables.XRSimpleInteractable>();
            }

            if (interaction.colliders.Count == 0)
            {
                Collider[] cs = obj.GetComponentsInChildren<Collider>();
                if (cs != null)
                {
                    foreach (Collider c in cs)
                    {
                        interaction.colliders.Add(c);
                    }
                }
            }

            interaction.interactionManager = interactionManager;
            interaction.selectEntered.AddListener(SelectInteraction);
            interaction.firstHoverEntered.AddListener(HoverEnterInteraction);
            interaction.hoverExited.AddListener(HoverExitInteraction);
        }
    }


    private GameObject instantiatePrefab(String name, PropertiesGAMA prop, bool initGame)
    {
        if (prop.prefabObj == null)
        {
            prop.loadPrefab(parameters.precision);
        }

        GameObject obj = Instantiate(prop.prefabObj);
        float scale = ((float)prop.size) / parameters.precision;
        obj.transform.localScale = new Vector3(scale, scale, scale);
        obj.SetActive(true);

        if (prop.hasCollider)
        {
            if (obj.TryGetComponent<LODGroup>(out var lod))
            {
                foreach (LOD l in lod.GetLODs())
                {
                    GameObject b = l.renderers[0].gameObject;
                    BoxCollider bc = b.AddComponent<BoxCollider>();
                    // b.tag = obj.tag;
                    // b.name = obj.name;
                    //bc.isTrigger = prop.isTrigger;
                }
            }
            else
            {
                BoxCollider bc = obj.AddComponent<BoxCollider>();
                // bc.isTrigger = prop.isTrigger;
            }
        }

        List<object> pL = new List<object>();
        pL.Add(obj);
        pL.Add(prop);
        if (!initGame) geometryMap.Add(name, pL);
        instantiateGO(obj, name, prop);
        return obj;
    }


    private void UpdateAgentsList()
    {
        ManageOtherInformation();
        List<string> toRemove = new List<string>(geometryMap.Keys);

        // foreach (List<object> obj in geometryMap.Values) {
        //((GameObject) obj[0]).SetActive(false);
        //}
        // toRemove.addAll(toRemoveAfter.k);
        GenerateGeometries(false, toRemove);


        // List<string> ids = new List<string>(geometryMap.Keys);
        foreach (string id in toRemove)
        {
            List<object> o = geometryMap[id];
            GameObject obj = (GameObject)o[0];
            obj.transform.position = new Vector3(0, -100, 0);
            geometryMap.Remove(id);
            GameObject.Destroy(obj);
        }

        //infoWorld = null;
    }

    protected virtual void ManageAttributes(List<Attributes> attributes)
    {
    }


    protected virtual void ManageOtherInformation()
    {
    }

    // ############################################# HANDLERS ########################################
    private void HandleConnectionStateChanged(ConnectionState state)
    {
        Debug.Log("HandleConnectionStateChanged: " + state);
        // player has been added to the simulation by the middleware
        if (state == ConnectionState.AUTHENTICATED)
        {
            Debug.Log("SimulationManager: Player added to simulation, waiting for initial parameters");
            UpdateGameState(GameState.LOADING_DATA);
        }
    }

    protected virtual void GenerateFutureDike()
    {
    }

    protected virtual void OtherUpdate()
    {
    }

    protected virtual void TriggerMainButton()
    {
    }

    protected void HoverEnterInteraction(HoverEnterEventArgs ev)
    {
        GameObject obj = ev.interactableObject.transform.gameObject;
        if ((obj.tag.Equals("dyke")) || ("dam").Equals(obj.tag))
            SimulationManagerSolo.ChangeColor(obj, Color.blue);
    }

    protected void HoverExitInteraction(HoverExitEventArgs ev)
    {
        GameObject obj = ev.interactableObject.transform.gameObject;
        if (obj.tag.Equals("dyke"))
        {
            SimulationManagerSolo.ChangeColor(obj, Color.gray);
        }
        else if (obj.tag.Equals("dam"))
        {
            SimulationManagerSolo.ChangeColor(obj, Color.magenta);
        }
    }

    protected void SelectInteraction(SelectEnterEventArgs ev)
    {
        if (_currentStage == "s_diking" && remainingTime <= 0.0)
        {
            GameObject grabbedObject = ev.interactableObject.transform.gameObject;

            if (("dyke").Equals(grabbedObject.tag) || ("dam").Equals(grabbedObject.tag))
            {
                Dictionary<string, string> args = new Dictionary<string, string> {
                         {"id", grabbedObject.name }
                    };
                ConnectionManager.Instance.SendExecutableAsk("destroy_dyke", args);
                
                remainingTime = timeWithoutInteraction;
            }
        }
    }

    static public void ChangeColor(GameObject obj, Color color)
    {
        Renderer[] renderers = obj.gameObject.GetComponentsInChildren<Renderer>();
        for (int i = 0; i < renderers.Length; i++)
        {
            renderers[i].material.color = color; // renderers[i].material.color == Color.red ? Color.gray : Color.red;
        }
    }

    protected virtual void ManageOtherMessages(string content)
    {
    }

    private void HandleServerMessageReceived(String firstKey, String content)
    {
        if (content == null || content.Equals("{}")) return;
        if (firstKey == null)
        {
            if (content.Contains("pong"))
            {
                currentTimePing = 0;
                return;
            }
            else if (content.Contains("pointsLoc"))
                firstKey = "pointsLoc";
            else if (content.Contains("precision"))
                firstKey = "precision";
            else if (content.Contains("properties"))
                firstKey = "properties";
            else if (content.Contains("endOfGame"))
                firstKey = "endOfGame";
            else
            {
                ManageOtherMessages(content);
                return;
            }
        }


        switch (firstKey)
        {
            // handle general informations about the simulation
            case "precision":

                parameters = ConnectionParameter.CreateFromJSON(content);
                converter = new CoordinateConverter(parameters.precision, GamaCRSCoefX, GamaCRSCoefY, GamaCRSCoefY,
                    GamaCRSOffsetX, GamaCRSOffsetY, GamaCRSOffsetZ);
                TimeSendPosition = (0.0f + parameters.minPlayerUpdateDuration) / (parameters.precision + 0.0f);
                Debug.Log("SimulationManager: Received simulation parameters");
                // Init ground and player
                // await Task.Run(() => InitGroundParameters());
                // await Task.Run(() => InitPlayerParameters()); 
                // handlePlayerParametersRequested = true;   
                handleGroundParametersRequested = true;
                handleGeometriesRequested = true;
                
                break;
            case "score":
                scoreM = ScoreMessage.CreateFromJSON(content);
                
                break;

            case "round":
                roundM = RoundMessage.CreateFromJSON(content);
                UIController.Instance.UpdateRound(roundM.round);
                break;
            
            case "dykeLength":
                dykeM = DykeLengthMessage.CreateFromJSON(content);
                break;

            case "damLength":
                damM = DamLengthMessage.CreateFromJSON(content);
                break;

            case "properties":
                propertiesGAMA = AllProperties.CreateFromJSON(content);
                propertyMap = new Dictionary<string, PropertiesGAMA>();
                foreach (PropertiesGAMA p in propertiesGAMA.properties)
                {
                    propertyMap.Add(p.id, p);
                }

                break;

            // handle agents while simulation is running
            case "pointsLoc":
                if (infoWorld == null)
                {
                    infoWorld = WorldJSONInfo.CreateFromJSON(content);
                }

                break;

            case "endOfGame":
                // Currently, the project does not use the same end-of-game logic as the template
                // Implement end-of-game logic
                break;

            case "rows":
                data = DEMData.CreateFromJSON(content);
                break;
            case "wallId":
                dataWall = WallInfo.CreateFromJSON(content);
                break;
            case "teleportId":
                // The Quang Binh Project currently does not use the teleport feature
                // Uncomment the line below in case the project needs the teleport feature in the future
                // dataTeleport = TeleportAreaInfo.CreateFromJSON(content);
                break;
            case "indexX":
                dataLoc = DEMDataLoc.CreateFromJSON(content);
                break;
            case "enableMove":
                // Move is enable by default
                // Uncomment the line below in case the project does not enable movement by default in the future
                // enableMove = EnableMoveInfo.CreateFromJSON(content);
                break;
            case "triggers":
                infoAnimation = AnimationInfo.CreateFromJSON(content);
                break;


            default:
                ManageOtherMessages(content);
                break;
        }
    }

    protected void ProcessRightHandTrigger()
    {
        if (rightHandTriggerButton != null && rightHandTriggerButton.action.triggered)
        {
            if (!_inTriggerPress)
            {
                _inTriggerPress = true;
                if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                {
                    StartPoint = raycastHit.point;
                    startPoint.transform.position = StartPoint;
                    DisplayFutureDike = true;
                    Debug.Log("Display future dike is true when selecting a point");
                }
            }
        }

        if (rightHandTriggerButton != null && !rightHandTriggerButton.action.inProgress)
        {
            if (_inTriggerPress)
            {
                _inTriggerPress = false;
                if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                {
                    EndPoint = raycastHit.point;
                    endPoint.transform.position = EndPoint;
                    // endPoint.active = true;
                    DisplayFutureDike = false;
                    Debug.Log("Display future dike is false when release the right hand");
                    if (FutureDike != null)
                    {
                        FutureDike.SetActive(false);
                        GameObject.DestroyImmediate(FutureDike);

                        FutureDike = null;
                    }

                    APITest.Instance.TestDrawDykeWithParams(StartPoint, EndPoint);
                }
            }
        }
    }

    private void HandleConnectionAttempted(bool success)
    {
        Debug.Log("SimulationManager: Connection attempt " + (success ? "successful" : "failed"));
        if (success)
        {
            if (IsGameState(GameState.MENU))
            {
                Debug.Log("SimulationManager: Successfully connected to middleware");
                UpdateGameState(GameState.WAITING);
            }
        }
        else
        {
            // stay in MENU state
            Debug.Log("Unable to connect to middleware");
        }
    }

    private void TryReconnect()
    {
        Dictionary<string, string> args = new Dictionary<string, string>
        {
            {
                "id",
                ConnectionManager.Instance.getUseMiddleware()
                    ? ConnectionManager.Instance.GetConnectionId()
                    : ("\"" + ConnectionManager.Instance.GetConnectionId() + "\"")
            }
        };

        ConnectionManager.Instance.SendExecutableAsk("ping_GAMA", args);

        currentTimePing = maxTimePing;
        Debug.Log("Sent Ping test");
    }

    // ############################################# UTILITY FUNCTIONS ########################################


    public bool IsGameState(GameState state)
    {
        return currentState == state;
    }


    public GameState GetCurrentState()
    {
        return currentState;
    }
}


// ############################################################
public enum GameState
{
    // not connected to middleware
    MENU,

    // connected to middleware, waiting for authentication
    WAITING,

    // connected to middleware, authenticated, waiting for initial data from middleware
    LOADING_DATA,

    // connected to middleware, authenticated, initial data received, simulation running
    GAME,
    END,
    CRASH
}


[Serializable]
public class ScoreMessage
{
    public int score;

    public static ScoreMessage CreateFromJSON(string jsonString)
    {
        return JsonUtility.FromJson<ScoreMessage>(jsonString);
    }
}

[Serializable]
public class RoundMessage
{
    public int round;

    public static RoundMessage CreateFromJSON(string jsonString)
    {
        return JsonUtility.FromJson<RoundMessage>(jsonString);
    }
}

[Serializable]
public class DykeLengthMessage
{
    public float dykeLength;

    public static DykeLengthMessage CreateFromJSON(string jsonString)
    {
        return JsonUtility.FromJson<DykeLengthMessage>(jsonString);
    }
}

[Serializable]
public class DamLengthMessage
{
    public float damLength;

    public static DamLengthMessage CreateFromJSON(string jsonString)
    {
        return JsonUtility.FromJson<DamLengthMessage>(jsonString);
    }
}

public static class Extensions
{
    public static bool TryGetComponent<T>(this GameObject obj, T result) where T : Component
    {
        return (result = obj.GetComponent<T>()) != null;
    }
}



