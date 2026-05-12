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
    private float minVisiblePercentage = 0.001f;
    private float minVisiblePercentagelod1 = 0.01f;
    private float minVisiblePercentagelod2 = 0.05f;

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
                if (lods.Length == 1)
                {
                    lods[0].screenRelativeTransitionHeight = minVisiblePercentage;
                }
                if (lods.Length == 2)
                {
                    lods[0].screenRelativeTransitionHeight = minVisiblePercentagelod1;
                    lods[1].screenRelativeTransitionHeight = minVisiblePercentage;
                }
                if (lods.Length == 3)
                {
                    lods[0].screenRelativeTransitionHeight = minVisiblePercentagelod2;
                    lods[1].screenRelativeTransitionHeight = minVisiblePercentagelod1;
                    lods[2].screenRelativeTransitionHeight = minVisiblePercentage;
                }
              //  int lastIndex = lods.Length - 1; 
               // lods[lastIndex].screenRelativeTransitionHeight = minVisiblePercentage;
                for(int i = 0; i < lods.Length; i++)
                {
                    Debug.Log(" lods[" +i+"]: " + lods[i].screenRelativeTransitionHeight);
                     
                }
                lodGroup.SetLODs(lods); 
                lodGroup.RecalculateBounds();
                count++; 
            }
           
        }

        if (verbose)
            Debug.Log($"✅ {count} LODGroups mis à jour (minVisiblePercentage = {minVisiblePercentage})");
    }
}