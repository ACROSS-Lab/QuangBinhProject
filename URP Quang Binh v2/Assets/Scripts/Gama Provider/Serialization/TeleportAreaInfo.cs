using System.Collections.Generic;
using UnityEngine;


[System.Serializable]
public class TeleportAreaInfo
{
    public List<int> offsetYGeom;

    public List<GAMAPoint> pointsGeom;

    public int height;

    public string teleportId;

    public static TeleportAreaInfo CreateFromJSON(string jsonString)
    {
        return JsonUtility.FromJson<TeleportAreaInfo>(jsonString);
    }
}