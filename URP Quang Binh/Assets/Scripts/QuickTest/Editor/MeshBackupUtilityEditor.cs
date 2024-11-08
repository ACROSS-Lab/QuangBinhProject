using UnityEditor;
using UnityEngine;

// This should match the namespace of your MeshBackupUtility

namespace QuickTest.Editor
{
    [CustomEditor(typeof(MeshBackupUtility))]
    public class MeshBackupUtilityEditor : UnityEditor.Editor
    {
        public override void OnInspectorGUI()
        {
            DrawDefaultInspector(); // Draws the default inspector options

            MeshBackupUtility myScript = (MeshBackupUtility)target;

            // Add a button for saving the mesh
            if (GUILayout.Button("Save Mesh"))
            {
                string path = EditorUtility.SaveFilePanel("Save Mesh Data", "", "SavedMesh.json", "json");
                if (!string.IsNullOrEmpty(path))
                {
                    myScript.SaveMesh(path);
                }
            }

            // Add a button for loading the mesh
            if (GUILayout.Button("Load Mesh"))
            {
                string path = EditorUtility.OpenFilePanel("Load Mesh Data", "", "json");
                if (!string.IsNullOrEmpty(path))
                {
                    myScript.LoadMesh(path);
                }
            }
        }
    }
}