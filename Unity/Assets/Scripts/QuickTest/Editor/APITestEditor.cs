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
        
            if (GUILayout.Button("Draw dyke"))
            {
                apiTest.TestDrawDyke();
            }

            if (GUILayout.Button("Remove dyke"))
            {
                apiTest.TestRemoveDyke();
            }

            if (GUILayout.Button("Pause"))
            {
                apiTest.TestPause();
            }

            if (GUILayout.Button("Resume"))
            {
                apiTest.TestResume();
            }

            if (GUILayout.Button("End"))
            {
                apiTest.TestEnd();
            }

            if (GUILayout.Button("Start Simulation"))
            {
                apiTest.TestStartSimulation();
            }
        }
    }
}