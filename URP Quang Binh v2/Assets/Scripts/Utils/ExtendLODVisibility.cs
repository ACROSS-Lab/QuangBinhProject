using UnityEngine;

public class ExtendLODVisibility : MonoBehaviour
{
    [Header("🔍 Ciblage")]
    [Tooltip("Laissez vide pour cibler toute la scène")]
    public Transform parentObject;

    [Tooltip("Laissez vide pour ignorer le filtrage par tag")]
    public string targetTag = "";

    [Header("🎚 Réglages LOD")]
    [Range(0f, 1f)]
    [Tooltip("Pourcentage minimum de taille à l'écran avant que l'objet disparaisse (plus petit = visible plus loin)")]
    public float minVisiblePercentage = 0.05f;
    public float minVisiblePercentagelod1 = 0.1f;

    [Tooltip("Afficher des logs dans la console")]
    public bool verbose = true;

    void Start()
    { 
        // Récupération des objets ciblés
        LODGroup[] lodGroups;

        if (parentObject != null)
            lodGroups = parentObject.GetComponentsInChildren<LODGroup>();
        else
            lodGroups = FindObjectsOfType<LODGroup>();

        int count = 0;

        foreach (LODGroup lodGroup in lodGroups)
        {
            // Filtrage par tag si défini
            if (!string.IsNullOrEmpty(targetTag) && lodGroup.gameObject.tag != targetTag)
                continue;

            LOD[] lods = lodGroup.GetLODs();

            // Ajuste uniquement le dernier LOD ("culled")
            if (lods.Length > 0)
            {
                int lastIndex = lods.Length - 1;
                lods[lastIndex].screenRelativeTransitionHeight = minVisiblePercentage;
                lodGroup.SetLODs(lods);
                lodGroup.RecalculateBounds();
                count++;
            }
            if (lods.Length > 1)
            {
                int lastIndex = lods.Length - 2;
                lods[lastIndex].screenRelativeTransitionHeight = minVisiblePercentagelod1;
                lodGroup.SetLODs(lods);
                lodGroup.RecalculateBounds();
                count++;
            }
        }

        if (verbose)
            Debug.Log($"✅ {count} LODGroups mis à jour (minVisiblePercentage = {minVisiblePercentage})");
    }
}