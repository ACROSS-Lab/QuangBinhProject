using UnityEngine;
using System.Collections.Generic;

[CreateAssetMenu(fileName = "New Language Data", menuName = "Localization/Language Data")]
public class LanguageData : ScriptableObject
{
    public List<LocalizedString> localizedStrings;

    void Reset()
    {
        var allKeyValues = System.Enum.GetValues(typeof(KeyString));

        if (localizedStrings == null)
        {
            localizedStrings = new List<LocalizedString>(allKeyValues.Length);
        }
        localizedStrings.Clear();

        foreach (object keyObject in allKeyValues)
        {
            KeyString key = (KeyString)keyObject;
            localizedStrings.Add(new LocalizedString { key = key, value = "" });
        }
    }
}

[System.Serializable]
public class LocalizedString
{
    public KeyString key;
    [TextArea(2, 5)]
    public string value;
}

public enum KeyString
{
    DykingPhase,
    FloodingPhase,
    Tutorial_Dyke_Destroying,
    Tutorial_Dyke_Building,
}