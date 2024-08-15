using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;


[System.Serializable]
public class WorldJSONInfo
{

    public List<int> position;
    public List<string> names;
    public List<string> keepNames;
    public List<string> propertyID;
    public List<GAMAPoint> pointsLoc;

    public List<GAMAPoint> pointsGeom;

    public List<int> ranking;
    public List<string> players;
    public int numTokens;
    public bool isInit;

    public double score;
    public double budget;
    public double ok_build_dyke_with_unity;
    public static WorldJSONInfo CreateFromJSON(string jsonString)
    {
        return JsonUtility.FromJson<WorldJSONInfo>(jsonString);
    } 

} 


[System.Serializable]
public class GAMAPoint
{
    public List<int> c;
}


