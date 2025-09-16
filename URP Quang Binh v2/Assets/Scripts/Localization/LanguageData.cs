using UnityEngine;
using System.Collections.Generic;

[CreateAssetMenu(fileName = "New Language Data", menuName = "Localization/Language Data")]
public class LanguageData : ScriptableObject
{
    public List<LocalizedString> localizedStrings;

    void Reset()
    {
        SyncWithEnum();
    }

    void OnValidate()
    {
        if (localizedStrings != null)
        {
            SyncWithEnum();
        }
    }

    void SyncWithEnum()
    {
        var allKeyValues = System.Enum.GetValues(typeof(KeyString));
        var newLocalizedStrings = new List<LocalizedString>();

        foreach (object keyObject in allKeyValues)
        {
            KeyString key = (KeyString)keyObject;

            LocalizedString existingEntry = null;
            foreach (var oldEntry in localizedStrings)
            {
                if (oldEntry.key == key)
                {
                    existingEntry = oldEntry;
                    break;
                }
            }

            if (existingEntry != null)
            {
                newLocalizedStrings.Add(existingEntry);
            }
            else
            {
                newLocalizedStrings.Add(new LocalizedString { key = key, value = "" });
            }
        }

        localizedStrings = newLocalizedStrings;
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
    Dyking_Phase,
    Flooding_Phase,
    Waiting_Text,
    Casualty_Text,
    Score_Text,
    Resources_Text,
    Button_Build_Dyke,
    Button_Restart,
    Tutorial_Dyke_Destroying,
    Tutorial_Dyke_Building,
    Start_Game_Text,
    Start_Button,
}