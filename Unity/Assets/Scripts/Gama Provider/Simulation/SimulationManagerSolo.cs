using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.XR.Interaction.Toolkit; 
using UnityEngine.InputSystem;



public class SimulationManagerSolo : SimulationManager
{
    protected bool isNight = false;
    protected override void TriggerMainButton()
    {
        //isNight = !isNight;
        //Light[] lights = FindObjectsOfType(typeof(Light)) as Light[];
        //foreach (Light light in lights)
        //{
        //    light.intensity = isNight ? 0 : 1.0f;
        //}

        {
                
            _dykePointCnt++;
            Debug.Log("Dyke point count: " + _dykePointCnt);
            GameObject groundObject = GameObject.Find("road");
            switch (_dykePointCnt)
            {
                case 1:
                {
                    if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                    {
                        GameObject hitGameObject = raycastHit.collider.gameObject;
                        _startPoint = raycastHit.point;
                        Debug.Log("hitGameObject: " + hitGameObject.name);
                        Debug.Log(
                            "startPoint of dyke: " + _startPoint.x + " " + _startPoint.y + " " + _startPoint.z);
                        Debug.Log("Coordinate of the ground: " + groundObject.transform.position.x + " " + groundObject.transform.position.y + " " + groundObject.transform.position.z);
                    }

                    //_startPoint = 
                    break;
                }
                case 2:
                {
                    if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                    {
                        GameObject hitGameObject = raycastHit.collider.gameObject;
                        _endPoint = raycastHit.point;
                        Debug.Log("hitGameObject: " + hitGameObject.name);
                        Debug.Log(
                            "endPoint of dyke: " + _endPoint.x + " " + _endPoint.y + " " + _endPoint.z);
                        
                        _apiTest.TestDrawDykeWithParams(_startPoint, _endPoint);

                        Debug.Log("Coordinate of the ground: " + groundObject.transform.position.x + " " + groundObject.transform.position.y + " " + groundObject.transform.position.z);
                        
                        _dykePointCnt = 0;
                    }

                    break;
                }
                default:
                    break;
            }
        }
    }

    protected override void ManageOtherInformation()
    {

    }

    protected override void OtherUpdate()
    {

    }

    protected override void ManageOtherMessages(string content)
    {

    }
    protected override void HoverEnterInteraction(HoverEnterEventArgs ev)
    {

        GameObject obj = ev.interactableObject.transform.gameObject;
        if (obj.tag.Equals("selectable") || obj.tag.Equals("car") || obj.tag.Equals("moto"))
            ChangeColor(obj, Color.blue);
    }

    protected override void HoverExitInteraction(HoverExitEventArgs ev)
    {
        GameObject obj = ev.interactableObject.transform.gameObject;
        if (obj.tag.Equals("selectable"))
        {
            bool isSelected = SelectedObjects.Contains(obj);

            ChangeColor(obj, isSelected ? Color.red : Color.gray);
        }
        else if (obj.tag.Equals("car") || obj.tag.Equals("moto"))
        {
            ChangeColor(obj, Color.white);
        }


    }

    protected override void SelectInteraction(SelectEnterEventArgs ev)
    {
        Debug.Log(ev.interactableObject.transform.gameObject.name);
        if (remainingTime <= 0.0)
        {
            GameObject grabbedObject = ev.interactableObject.transform.gameObject;
            
            if (("selectable").Equals(grabbedObject.tag))
            {
                Dictionary<string, string> args = new Dictionary<string, string> {
                         {"id", grabbedObject.name }
                    };
                ConnectionManager.Instance.SendExecutableAsk("update_hotspot", args);
                bool newSelection = !SelectedObjects.Contains(grabbedObject);
                if (newSelection)
                    SelectedObjects.Add(grabbedObject);
                else
                    SelectedObjects.Remove(grabbedObject);
                ChangeColor(grabbedObject, newSelection ? Color.red : Color.gray);

                remainingTime = timeWithoutInteraction;
            }
            else if (grabbedObject.tag.Equals("car") || grabbedObject.tag.Equals("moto"))
            {
                Dictionary<string, string> args = new Dictionary<string, string> {
                         {"id", grabbedObject.name }
                    };
                ConnectionManager.Instance.SendExecutableAsk("remove_vehicle", args);
                grabbedObject.SetActive(false);
                //toDelete.Add(grabbedObject);

            }

            /*else
            {
                
                _dykePointCnt++;
                Debug.Log("Dyke point count: " + _dykePointCnt);

                switch (_dykePointCnt)
                {
                    case 1:
                    {
                        if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                        {
                            GameObject hitGameObject = raycastHit.collider.gameObject;
                            _startPoint = raycastHit.point;
                            Debug.Log("hitGameObject: " + hitGameObject.name);
                            Debug.Log(
                                "startPoint of dyke: " + _startPoint.x + " " + _startPoint.y + " " + _startPoint.z);
                        }

                        //_startPoint = 
                        break;
                    }
                    case 2:
                    {
                        if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                        {
                            GameObject hitGameObject = raycastHit.collider.gameObject;
                            _endPoint = raycastHit.point;
                            Debug.Log("hitGameObject: " + hitGameObject.name);
                            Debug.Log(
                                "startPoint of dyke: " + _endPoint.x + " " + _endPoint.y + " " + _endPoint.z);
                        }

                        break;
                    }
                    default:
                        break;
                }
            }
            */
        }

    }
}