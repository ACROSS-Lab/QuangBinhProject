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
        GameObject water = GameObject.Find("water_0.0");

        if (water != null)
        {
            Debug.Log("Water position: " + water.transform.position.x + " " + water.transform.position.y + " " + water.transform.position.z);
            Debug.Log("Water scale: " + water.transform.localScale.x + " " + water.transform.localScale.y + " " + water.transform.localScale.z);
        }
        //isNight = !isNight;
        //Light[] lights = FindObjectsOfType(typeof(Light)) as Light[];
        //foreach (Light light in lights)
        //{
        //    light.intensity = isNight ? 0 : 1.0f;
        //}
        if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
        {
            _dykePointCnt++;
            Debug.Log("Dyke point count: " + _dykePointCnt);
            GameObject groundObject = GameObject.Find("road");
            switch (_dykePointCnt)
            {
                case 1:
                {
                    {
                        GameObject hitGameObject = raycastHit.collider.gameObject;
                        _startPoint = raycastHit.point;
                            startPoint.transform.position = _startPoint;
                            startPoint.active = true;
                            endPoint.active = false;
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
                    {
                        GameObject hitGameObject = raycastHit.collider.gameObject;
                        _endPoint = raycastHit.point;
                            endPoint.transform.position = _endPoint;
                            endPoint.active = true;
                            Debug.Log("hitGameObject: " + hitGameObject.name);
                        Debug.Log(
                            "endPoint of dyke: " + _endPoint.x + " " + _endPoint.y + " " + _endPoint.z);
                        
                        _apiTest.TestDrawDykeWithParams(_startPoint, _endPoint);

                        Debug.Log("Coordinate of the ground: " + groundObject.transform.position.x + " " + groundObject.transform.position.y + " " + groundObject.transform.position.z);
                        GameObject[] dykeObjects = GameObject.FindGameObjectsWithTag("dyke");
                        
                        Debug.Log("Number of dykes: " + dykeObjects.Length);
                        _dykePointCnt = 0;
                    }
                    break;
                }
                /*default:
                {
                    _dykePointCnt = 0;
                       endPoint.active = false;
                        endPoint.active = false;
                        break;
                }*/
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
  

   
   
}