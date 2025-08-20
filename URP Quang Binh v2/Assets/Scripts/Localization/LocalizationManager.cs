using UnityEngine;
using System.Collections.Generic;

public class LocalizationManager : MonoBehaviour
{
    public static LocalizationManager Instance { get; private set; }

    [SerializeField] LanguageData currentLanguageData;
    Dictionary<KeyString, string> localizedText;

    public delegate void LanguageChanged();
    public static event LanguageChanged OnLanguageChanged;

    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
            LoadLocalizedText();
        }
        else
        {
            Destroy(gameObject);
        }
    }

    private void LoadLocalizedText()
    {
        localizedText = new Dictionary<KeyString, string>();
        if (currentLanguageData != null)
        {
            foreach (var localizedString in currentLanguageData.localizedStrings)
            {
                localizedText[localizedString.key] = localizedString.value;
            }
        }
    }

    public string GetLocalizedValue(KeyString key)
    {
        if (localizedText.ContainsKey(key))
        {
            return localizedText[key];
        }
        Debug.LogError("Localized key not found: " + key);
        return key.ToString();
    }

    public void SetLanguage(LanguageData newLanguageData)
    {
        currentLanguageData = newLanguageData;
        LoadLocalizedText();
        OnLanguageChanged?.Invoke();
    }
}