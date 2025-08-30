using System.Collections.Generic;
using UnityEngine;


public class SimulationManagerSolo : SimulationManager
{
    PropertiesGAMA propFutureDike, propFalseDike;

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

        propFalseDike = new PropertiesGAMA
        {
            red = 255,
            blue = 0,
            green = 0,
            hasCollider = false,
            hasPrefab = false,
            height = 40 * 10000,
            is3D = true,
            visible = true
        };
    }

    protected override void GenerateFutureDike()
    {
        // Debug.Log("Will generate a future dike");
        if (polyGen == null)
        {
            polyGen = PolygonGenerator.GetInstance();
            polyGen.Init(converter);
        }

        if (rightXRRayInteractor.TryGetCurrent3DRaycastHit(out RaycastHit raycastHit))
        {
            if (FutureDike != null)
            {
                FutureDike.SetActive(false);

                GameObject.DestroyImmediate(FutureDike);
            }

            Vector2[] pts = new Vector2[5];
            Vector3 _endPoint = raycastHit.point;
            float distance = Vector3.Distance(StartPoint, _endPoint);
            Vector2 direction = new Vector2(_endPoint.x - StartPoint.x, _endPoint.z - StartPoint.z).normalized;
            Vector2 Per = Vector2.Perpendicular(direction);
            Per = new Vector2(Per.x * 10.0f, Per.y * 10.0f);

            pts[0] = new Vector2(StartPoint.x + Per.x, StartPoint.z + Per.y);
            pts[1] = new Vector2(_endPoint.x + Per.x, _endPoint.z + Per.y);
            pts[2] = new Vector2(_endPoint.x - Per.x, _endPoint.z - Per.y);
            pts[3] = new Vector2(StartPoint.x - Per.x, StartPoint.z - Per.y);
            pts[4] = pts[0];


            FutureDike = polyGen.GeneratePolygons(false, "FutureDike", pts, remaining_resources - distance > 0 ? propFutureDike : propFalseDike, parameters.precision);
        }
    }

    protected override void OtherUpdate()
    {
        if (DisplayFutureDike)
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
            int color_id = attributes[i].color_id;

            if (length != 0)
            {
                obj.transform.localScale = new Vector3(obj.transform.localScale.y, obj.transform.localScale.y, length / 36);
                
                if(modifiedDykes.ContainsKey(name) && !modifiedDykes[name])
                {
                    obj.transform.localEulerAngles = new Vector3(0, -rotation, 0);
                    
                    PlayerColor playerColor = playerColors[color_id];
                    if(obj.CompareTag("dyke")) obj.GetComponent<MeshRenderer>().material = playerColor.dykeMaterial;
                    else if(obj.CompareTag("dam")) obj.GetComponent<MeshRenderer>().material = playerColor.damMaterial;
                    
                    modifiedDykes[name] = true;
                }
            }

            else if (status != 0)
            {
                if (!obj.activeInHierarchy) obj.SetActive(true);
                GameObject redIndicator = obj.transform.GetChild(0).gameObject;
                if (status == -1)
                {
                    if(!redIndicator.activeInHierarchy) redIndicator.SetActive(true);
                }
                else if (status == 1)
                {
                    if(redIndicator.activeInHierarchy) redIndicator.SetActive(false);
                }
            }
            
        }
    }
}