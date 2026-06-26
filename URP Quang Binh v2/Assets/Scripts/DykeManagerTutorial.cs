using System.Collections.Generic;
using System.Linq;
using HutongGames.PlayMaker.ActionsInternal;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.XR.Interaction.Toolkit.Interactables;
using UnityEngine.XR.Interaction.Toolkit.Interactors;

public class DykeManagerTutorial : MonoBehaviour
{
    [Header("Input Actions")]
    [SerializeField] InputActionReference primaryRightHandButton = null;
    [SerializeField] InputActionReference rightHandTriggerButton = null;
    [SerializeField] XRRayInteractor rightXRRayInteractor;
    [SerializeField] Collider[] snapPoints;
    [SerializeField] GameObject dykePrefab;
    [SerializeField] Material selectedMaterial;
    [SerializeField] float perMultiplier = 0.1f;
    [SerializeField] int heightDivision = 10;
    [SerializeField] float scaleMultiplier = 0.1f;
    [SerializeField] GameObject dykeToDestroy;

    [Header("For PlayMaker")]
    public int dykeBuilt = 0;
    public int dykeDestroyed = 0;

    bool inTriggerPress, displayFutureDike;
    Vector3 startPoint, endPoint;
    Collider startCollider;
    GameObject futureDyke;
    PropertiesGAMA propFutureDike;
    PolygonGenerator polyGen = null;
    Dictionary<GameObject, Material> selectedHoveringDykes;

    void Start()
    {
        propFutureDike = new PropertiesGAMA
        {
            red = 0,
            blue = 0,
            green = 255,
            hasCollider = false,
            hasPrefab = false,
            height = 1,
            is3D = true,
            visible = true
        };

        selectedHoveringDykes = new Dictionary<GameObject, Material>();

        AddInteraction(dykeToDestroy);
    }

    void Update()
    {
        ProcessRightHandTrigger();

        if (displayFutureDike)
        {
            GenerateFutureDike();
        }
    }

    void ProcessRightHandTrigger()
    {
        if (rightHandTriggerButton != null && rightHandTriggerButton.action.triggered)
        {
            if (!inTriggerPress)
            {
                inTriggerPress = true;
                if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                {
                    if (snapPoints.Contains(raycastHit.collider))
                    {
                        startCollider = raycastHit.collider;
                        startPoint = startCollider.transform.position;
                        displayFutureDike = true;
                    }
                }
            }
        }

        if (rightHandTriggerButton != null && !rightHandTriggerButton.action.inProgress)
        {
            displayFutureDike = false;
            if (futureDyke != null)
            {
                DestroyImmediate(futureDyke);
                futureDyke = null;
            }

            if (inTriggerPress)
            {
                inTriggerPress = false;
                if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                {
                    if (snapPoints.Contains(raycastHit.collider) && raycastHit.collider != startCollider)
                    {
                        endPoint = raycastHit.collider.transform.position;
                        DrawNewDyke();
                    }
                }
            }
        }
    }

    void GenerateFutureDike()
    {
        if (polyGen == null)
        {
            polyGen = PolygonGenerator.GetInstance();
        }

        if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
        {
            if (futureDyke != null)
            {
                DestroyImmediate(futureDyke);
            }

            Vector2[] pts = new Vector2[5];
            Vector3 _endPoint = raycastHit.point;
            Vector2 direction = new Vector2(_endPoint.x - startPoint.x, _endPoint.z - startPoint.z).normalized;
            Vector2 Per = Vector2.Perpendicular(direction);
            Per = new Vector2(Per.x * perMultiplier, Per.y * perMultiplier);

            pts[0] = new Vector2(startPoint.x + Per.x, startPoint.z + Per.y);
            pts[1] = new Vector2(_endPoint.x + Per.x, _endPoint.z + Per.y);
            pts[2] = new Vector2(_endPoint.x - Per.x, _endPoint.z - Per.y);
            pts[3] = new Vector2(startPoint.x - Per.x, startPoint.z - Per.y);
            pts[4] = pts[0];


            futureDyke = polyGen.GeneratePolygons(false, "FutureDyke", pts, propFutureDike, heightDivision);
        }
    }

    void DrawNewDyke()
    {
        GameObject dyke = Instantiate(dykePrefab, transform);
        dyke.transform.position = (startPoint + endPoint) / 2;

        Vector3 direction = endPoint - startPoint;
        direction.y = 0;
        Quaternion quaternion = Quaternion.LookRotation(direction, Vector3.up);
        dyke.transform.rotation = quaternion;

        float distance = Vector3.Distance(startPoint, endPoint);
        dyke.transform.localScale = new Vector3(dyke.transform.localScale.x * scaleMultiplier, dyke.transform.localScale.y * scaleMultiplier, distance / 36);

        // AddInteraction(dyke);

        dykeBuilt++;
    }

    void AddInteraction(GameObject dyke)
    {
        dyke.AddComponent<BoxCollider>();
        XRBaseInteractable interaction = dyke.AddComponent<XRSimpleInteractable>();
        interaction.selectEntered.AddListener(SelectInteraction);
        interaction.firstHoverEntered.AddListener(HoverEnterInteraction);
        interaction.hoverExited.AddListener(HoverExitInteraction);
    }

    void HoverExitInteraction(HoverExitEventArgs ev)
    {
        if (ev.interactableObject == null) return;
        GameObject obj = ev.interactableObject.transform.gameObject;
        if (selectedHoveringDykes.ContainsKey(obj))
        {
            obj.GetComponent<MeshRenderer>().material = selectedHoveringDykes[obj];
            selectedHoveringDykes.Remove(obj);
        }
    }

    void HoverEnterInteraction(HoverEnterEventArgs ev)
    {
        if (ev.interactableObject == null) return;
        GameObject obj = ev.interactableObject.transform.gameObject;
        if (!selectedHoveringDykes.ContainsKey(obj))
        {
            selectedHoveringDykes.Add(obj, obj.GetComponent<MeshRenderer>().material);
            obj.GetComponent<MeshRenderer>().material = selectedMaterial;
        }
    }

    void SelectInteraction(SelectEnterEventArgs ev)
    {
        XRSimpleInteractable interaction = ev.interactableObject as XRSimpleInteractable;
        if (interaction != null)
        {
            interaction.selectEntered.RemoveListener(SelectInteraction);
            interaction.firstHoverEntered.RemoveListener(HoverEnterInteraction);
            interaction.hoverExited.RemoveListener(HoverExitInteraction);

            Destroy(interaction.gameObject);

            dykeDestroyed++;
        }
    }

    public void ActivateMainScene()
    {
        SceneManager.LoadScene("Main Scene - ArtUpdate_Flood");
    }

    public void OnTriggerActivate()
    {
        Debug.Log("Trigger Pressed");
    }
}
