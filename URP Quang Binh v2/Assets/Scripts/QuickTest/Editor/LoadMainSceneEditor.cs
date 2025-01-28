using UnityEditor;
using UnityEngine;

namespace QuickTest.Editor
{
    [CustomEditor(typeof(LoadMainScene))]
    public class LoadMainSceneEditor : UnityEditor.Editor
    {
        public override void OnInspectorGUI()
        {
            // Draw the default inspector for SkipScene
            DrawDefaultInspector();

            // Reference to the SkipScene script
            LoadMainScene skipScene = (LoadMainScene)target;

            // Create a button in the inspector
            if (GUILayout.Button("Load Scene"))
            {
                // Call the method to load the scene
                skipScene.LoadScene();
            }
        }
    }
}