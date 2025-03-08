using System.Collections.Generic;
using UnityEngine;


[System.Serializable]
public class ConnectionParameter
{
    public int precision;
    public int[] position;
    public int[] world;

    public List<string> hotspots;
    public int minPlayerUpdateDuration;

    public static ConnectionParameter CreateFromJSON(string jsonString)
    {
        return JsonUtility.FromJson<ConnectionParameter>(jsonString);
    }
}