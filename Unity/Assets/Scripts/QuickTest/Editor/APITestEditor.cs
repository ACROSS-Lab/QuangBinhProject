using UnityEditor;
using UnityEngine;

namespace QuickTest.Editor
{
    [CustomEditor(typeof(APITest))]
    public class APITestEditor : UnityEditor.Editor
    {
        public override void OnInspectorGUI()
        {
            DrawDefaultInspector();

            APITest apiTest = (APITest)target;

            if (GUILayout.Button("Set in tutorial"))
            {
                apiTest.TestSetInTutorial();
            }

            if (GUILayout.Button("Set in game"))
            {
                apiTest.TestSetInGame();
            }
        
            if (GUILayout.Button("Draw dyke"))
            {
                apiTest.TestDrawDyke();
            }

            if (GUILayout.Button("Remove dyke"))
            {
                apiTest.TestRemoveDyke();
            }
        }
    }
}