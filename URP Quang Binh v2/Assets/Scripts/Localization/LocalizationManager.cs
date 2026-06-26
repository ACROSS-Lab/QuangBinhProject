//MAKE SURE THAT THE CSV FILE IS IN THE "Resources/Localizaion" FOLDER IN YOUR UNITY PROJECT 
//AND THE FILE ITSELF MUST NOT CONTAIN COMMAS (,) OR LINE BREAKS (\n, \r)
//IN THE LOCALIZED STRINGS TO AVOID PARSING ISSUES.

using UnityEngine;
using System.Collections.Generic;

public class LocalizationManager : MonoBehaviour
{
    public static LocalizationManager Instance { get; private set; }

    private const string CsvFilePath = "Localization/LocalizationData"; 

    private Dictionary<string, Dictionary<string, string>> localizedData;
    private string currentLanguage = "English";

    public delegate void LanguageChanged();
    public static event LanguageChanged OnLanguageChanged;

    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
            LoadLocalizationData();
        }
        else
        {
            Destroy(gameObject);
        }
    }

    private void LoadLocalizationData()
    {
        localizedData = new Dictionary<string, Dictionary<string, string>>();
        
        TextAsset csvFile = Resources.Load<TextAsset>(CsvFilePath);

        if (csvFile == null)
        {
            Debug.LogError($"Localization CSV not found at 'Resources/{CsvFilePath}'.");
            return;
        }

        string[] lines = csvFile.text.Split(new[] { '\r', '\n' }, System.StringSplitOptions.RemoveEmptyEntries);
        if (lines.Length < 2) return;

        string[] headers = lines[0].Split(',');
        for (int i = 1; i < headers.Length; i++)
        {
            localizedData[headers[i].Trim()] = new Dictionary<string, string>();
        }

        for (int i = 1; i < lines.Length; i++)
        {
            string[] values = lines[i].Split(',');
            string key = values[0].Trim();

            for (int j = 1; j < values.Length && j < headers.Length; j++)
            {
                string language = headers[j].Trim();
                string value = values[j].Trim();
                localizedData[language][key] = value;
            }
        }

        Debug.Log("Localization data loaded.");
    }

    public void SetLanguage(string languageName)
    {
        if (localizedData.ContainsKey(languageName))
        {
            currentLanguage = languageName;
            OnLanguageChanged?.Invoke();
            Debug.Log($"Language changed to: {currentLanguage}");
        }
        else
        {
            Debug.LogWarning($"Language '{languageName}' not found in localization data.");
        }
    }

    public string GetLocalizedValue(string key)
    {
        if (localizedData.ContainsKey(currentLanguage) && localizedData[currentLanguage].ContainsKey(key))
        {
            return localizedData[currentLanguage][key];
        }

        Debug.LogWarning($"Localization key '{key}' not found for language '{currentLanguage}'.");
        return key;
    }
}