using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.XR.Interaction.Toolkit.Interactables;
using UnityEngine.XR.Interaction.Toolkit.Interactors;

public class DykeManagerTutorial : MonoBehaviour
{
    [SerializeField] InputActionReference rightHandTriggerButton = null;
    [SerializeField] XRRayInteractor rightXRRayInteractor;
    [SerializeField] GameObject dykePrefab;
    [SerializeField] Material selectedMaterial;
    bool inTriggerPress, displayFutureDike;
    Vector3 StartPoint, EndPoint;
    GameObject futureDike;
    PropertiesGAMA propFutureDike;
    protected PolygonGenerator polyGen;
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
            height = 40 * 10000,
            is3D = true,
            visible = true
        };

        polyGen = GetComponent<PolygonGenerator>();
        selectedHoveringDykes = new Dictionary<GameObject, Material>();
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
                    StartPoint = raycastHit.point;
                    displayFutureDike = true;
                    Debug.Log("Display future dike is true when selecting a point");
                }
            }
        }

        if (rightHandTriggerButton != null && !rightHandTriggerButton.action.inProgress)
        {
            if (inTriggerPress)
            {
                inTriggerPress = false;
                if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                {
                    EndPoint = raycastHit.point;
                    displayFutureDike = false;
                    Debug.Log("Display future dike is false when release the right hand");
                    if (futureDike != null)
                    {
                        futureDike.SetActive(false);
                        DestroyImmediate(futureDike);

                        futureDike = null;
                    }
                }
                DrawNewDyke();
            }
        }
    }

    void GenerateFutureDike()
    {
        if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
        {
            if (futureDike != null)
            {
                DestroyImmediate(futureDike);
            }

            Vector2[] pts = new Vector2[5];
            Vector3 _endPoint = raycastHit.point;
            Vector2 direction = new Vector2(_endPoint.x - StartPoint.x, _endPoint.z - StartPoint.z).normalized;
            Vector2 Per = Vector2.Perpendicular(direction);
            Per = new Vector2(Per.x * 10.0f, Per.y * 10.0f);

            pts[0] = new Vector2(StartPoint.x + Per.x, StartPoint.z + Per.y);
            pts[1] = new Vector2(_endPoint.x + Per.x, _endPoint.z + Per.y);
            pts[2] = new Vector2(_endPoint.x - Per.x, _endPoint.z - Per.y);
            pts[3] = new Vector2(StartPoint.x - Per.x, StartPoint.z - Per.y);
            pts[4] = pts[0];


            futureDike = polyGen.GeneratePolygons(false, null, pts, propFutureDike, 1);
        }
    }

    void DrawNewDyke()
    {
        GameObject dyke = Instantiate(dykePrefab);
        dyke.transform.position = (StartPoint + EndPoint) / 2;

        Vector3 direction = EndPoint - StartPoint;
        direction.y = 0;
        Quaternion quaternion = Quaternion.LookRotation(direction, Vector3.up);
        dyke.transform.rotation = quaternion;

        float distance = Vector3.Distance(StartPoint, EndPoint);
        dyke.transform.localScale = new Vector3(dyke.transform.localScale.x, dyke.transform.localScale.y, distance / 36);

        XRBaseInteractable interaction = dyke.AddComponent<XRSimpleInteractable>();
        interaction.selectEntered.AddListener(SelectInteraction);
        interaction.firstHoverEntered.AddListener(HoverEnterInteraction);
        interaction.hoverExited.AddListener(HoverExitInteraction);
    }

    void HoverExitInteraction(HoverExitEventArgs ev)
    {
        GameObject obj = ev.interactableObject.transform.gameObject;
        if(selectedHoveringDykes.ContainsKey(obj))
        {
            obj.GetComponent<MeshRenderer>().material = selectedHoveringDykes[obj];
            selectedHoveringDykes.Remove(obj);
        }
    }

    void HoverEnterInteraction(HoverEnterEventArgs ev)
    {
        GameObject obj = ev.interactableObject.transform.gameObject;
        if (!selectedHoveringDykes.ContainsKey(obj))
        {
            selectedHoveringDykes.Add(obj, obj.GetComponent<MeshRenderer>().material);
            obj.GetComponent<MeshRenderer>().material = selectedMaterial;
        }
    }

    void SelectInteraction(SelectEnterEventArgs ev)
    {
        GameObject obj = ev.interactableObject.transform.gameObject;
        DestroyImmediate(obj);
    }
}
