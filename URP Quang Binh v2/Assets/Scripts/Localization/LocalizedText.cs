using TMPro;
using UnityEngine;

[RequireComponent(typeof(TextMeshProUGUI))] 
public class LocalizedText : MonoBehaviour
{
    [SerializeField] KeyString localizationKey;
    TextMeshProUGUI textComponent;

    private void Start()
    {
        textComponent = GetComponent<TextMeshProUGUI>();
        UpdateText();
        LocalizationManager.OnLanguageChanged += UpdateText;
    }

    private void OnDestroy()
    {
        LocalizationManager.OnLanguageChanged -= UpdateText;
    }

    private void UpdateText()
    {
        if (textComponent != null)
        {
            textComponent.text = LocalizationManager.Instance.GetLocalizedValue(localizationKey);
        }
    }
}