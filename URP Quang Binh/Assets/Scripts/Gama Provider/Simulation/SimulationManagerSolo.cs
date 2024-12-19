using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.XR.Interaction.Toolkit; 
using UnityEngine.InputSystem;



public class SimulationManagerSolo : SimulationManager
{
    



    protected override void GenerateFutureDike()
    {
        if (polyGen == null)
        {
            polyGen = PolygonGenerator.GetInstance();
            polyGen.Init(converter);
        }

       if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
                {

                if(FutureDike != null)
            {
                FutureDike.SetActive(false);

                GameObject.DestroyImmediate(FutureDike);
            }
                 Vector2[] pts = new Vector2[5];
                  Vector3 _endPoint = raycastHit.point;
                    Vector2 direction = new Vector2(_endPoint.x - _startPoint.x, _endPoint.z - _startPoint.z).normalized;
                    Vector2 Per = Vector2.Perpendicular(direction);
                    Per = new Vector2(Per.x * 10.0f, Per.y * 10.0f);
                   
                    pts[0] = new Vector2(_startPoint.x + Per.x, _startPoint.z + Per.y);
                    pts[1] = new Vector2(_endPoint.x + Per.x, _endPoint.z + Per.y);
                    pts[2] = new Vector2(_endPoint.x - Per.x, _endPoint.z - Per.y);
                    pts[3] = new Vector2(_startPoint.x - Per.x, _startPoint.z - Per.y);
                    pts[4] = pts[0];
       

                 FutureDike = polyGen.GeneratePolygons(false, "FutureDike", pts, propFutureDike, parameters.precision);

                }
        

    }

    protected override void HoverEnterInteraction(HoverEnterEventArgs ev)
    {
        GameObject obj = ev.interactableObject.transform.gameObject;
        if (obj.tag.Equals("dyke"))
            SimulationManagerSolo.ChangeColor(obj, Color.blue);
    }

    protected override void HoverExitInteraction(HoverExitEventArgs ev)
    {
        GameObject obj = ev.interactableObject.transform.gameObject;
        if (obj.tag.Equals("dyke"))
        {
            SimulationManagerSolo.ChangeColor(obj, new Color(204,119,34));
        }
        
    } 

    protected override void SelectInteraction(SelectEnterEventArgs ev)
    {

        if (remainingTime <= 0.0)
        {
            GameObject grabbedObject = ev.interactableObject.transform.gameObject;

            if (("dyke").Equals(grabbedObject.tag))
            {
                Dictionary<string, string> args = new Dictionary<string, string> {
                         {"id", grabbedObject.name }
                    };
                ConnectionManager.Instance.SendExecutableAsk("destroy_dyke", args);
                remainingTime = timeWithoutInteraction;
            }
            
        }

    }
    protected override void ManageOtherInformation()
    {

    }  

    protected override void OtherUpdate()
    {
       
        if (DisplayFutureDike)
        {
            GenerateFutureDike();
        }
    }

    protected override void ManageOtherMessages(string content)
    {

    }
  

   
   
}