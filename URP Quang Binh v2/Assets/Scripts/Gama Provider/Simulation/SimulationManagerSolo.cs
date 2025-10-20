using System.Collections.Generic;
using UnityEngine;


public class SimulationManagerSolo : SimulationManager
{

    
    protected override void GenerateFutureDike()
    {
       if(rightXRRayInteractor != null && rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit)) {
            GenerateFutureDike(raycastHit.point);
        }

    }

    protected override void OtherUpdate()
    { 
        if (!UseKeyboard && DisplayFutureDike)
        {
            // Debug.Log("Display future dike is true at other update");
            GenerateFutureDike();
        }
    }

    protected override void ManageAttributes(List<Attributes> attributes)
    {
        for (int i = 0; i < infoWorld.names.Count; i++)
        {
            string name = infoWorld.names[i];
            if(!geometryMap.ContainsKey(name)) return;
            object[] o = geometryMap[name];
            GameObject obj = (GameObject)o[0];
            
            float length = attributes[i].length;
            float rotation = attributes[i].rotation;
            int status = attributes[i].status;

            if(length != 0)
            {
                obj.transform.localScale = new Vector3(obj.transform.localScale.y, obj.transform.localScale.y, length/36);
                obj.transform.localEulerAngles = new Vector3(0, -rotation, 0);
            }

            else if(status != 0) 
            {
                if(!obj.activeInHierarchy) obj.SetActive(true);
                if(status == -1)
                {
                    obj.transform.GetChild(0).gameObject.SetActive(true);
                    obj.transform.GetChild(1).localEulerAngles = new Vector3(90, 90, 0);
                }
                else if(status == 1)
                {
                    obj.transform.GetChild(0).gameObject.SetActive(false);
                    obj.transform.GetChild(1).localEulerAngles = new Vector3(0, 90, 0);
                } 
            }
            
        }
    }
}