using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.InputSystem;


public class SimulationManagerSolo : SimulationManager
{
    // Method to check if the point (only considering x and z) is within the water collider's bounds
    bool IsPointInWaterBounds(Collider waterCollider, Vector2 pointXZ)
    {
        // Get the collider's bounds in world space
        Bounds bounds = waterCollider.bounds;

        // Convert bounds to 2D (ignore y)
        Vector2 boundsMin = new Vector2(bounds.min.x, bounds.min.z);
        Vector2 boundsMax = new Vector2(bounds.max.x, bounds.max.z);

        // Check if the point is within the bounds (x and z only)
        return pointXZ.x >= boundsMin.x && pointXZ.x <= boundsMax.x && pointXZ.y >= boundsMin.y &&
               pointXZ.y <= boundsMax.y;
    }

    protected override void GenerateFutureDike()
    {
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
            Vector2 direction = new Vector2(_endPoint.x - _startPoint.x, _endPoint.z - _startPoint.z).normalized;
            Vector2 Per = Vector2.Perpendicular(direction);
            Per = new Vector2(Per.x * 10.0f, Per.y * 10.0f);

            pts[0] = new Vector2(_startPoint.x + Per.x, _startPoint.z + Per.y);
            pts[1] = new Vector2(_endPoint.x + Per.x, _endPoint.z + Per.y);
            pts[2] = new Vector2(_endPoint.x - Per.x, _endPoint.z - Per.y);
            pts[3] = new Vector2(_startPoint.x - Per.x, _startPoint.z - Per.y);
            pts[4] = pts[0];

            if (currentStage != "s_flooding")
                FutureDike = polyGen.GeneratePolygons(false, "FutureDike", pts, propFutureDike, parameters.precision);
            else
            {
                GameObject waterObject = GameObject.FindGameObjectWithTag("water");

                bool collidedWater = false;

                // Check if the water object has a collider
                if (waterObject != null && waterObject.GetComponent<MeshCollider>() != null)
                {
                    MeshCollider waterCollider = waterObject.GetComponent<MeshCollider>();
                    Debug.Log("found mesh collider for water");
                    // Iterate through all points and check if they are inside the water object's collider
                    foreach (Vector2 point in pts)
                    {
                        // Check if the point is within the bounds of the water object (only considering x and z)
                        if (IsPointInWaterBounds(waterCollider, point))
                        {
                            collidedWater = true;
                            Debug.Log("Point " + point + " is inside the water.");
                            break;
                        }
                        else
                        {
                            Debug.Log("Point " + point + " is outside the water.");
                        }
                    }

                    if (collidedWater)
                        FutureDike = polyGen.GeneratePolygons(false, "FutureDike", pts, propDeletedDike,
                            parameters.precision);
                    else
                        FutureDike = polyGen.GeneratePolygons(false, "FutureDike", pts, propFutureDike,
                            parameters.precision);
                }
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