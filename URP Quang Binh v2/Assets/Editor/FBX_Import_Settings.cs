using UnityEngine;
using UnityEditor;

public class NoMaterialImportHandler : AssetPostprocessor
{
    // 🔹 Menu manuel pour désactiver l'import de matériaux
    [MenuItem("Tools/Models/Disable Materials On Selected")]
    static void DisableMaterialsOnSelected()
    {
        foreach (var obj in Selection.objects)
        {
            string path = AssetDatabase.GetAssetPath(obj);
            if (AssetImporter.GetAtPath(path) is ModelImporter importer)
            {
                importer.materialImportMode = ModelImporterMaterialImportMode.None;
                importer.userData = "NoMaterialsApplied"; // Tag pour info
                importer.SaveAndReimport();
            }
        }

        Debug.Log("✅ Matériaux désactivés sur les FBX sélectionnés.");
    }
}
