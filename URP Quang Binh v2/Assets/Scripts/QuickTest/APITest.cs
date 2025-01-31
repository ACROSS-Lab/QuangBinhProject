using System.Collections.Generic;
using Gama_Provider.Simulation;
using UnityEngine;

namespace QuickTest
{
    public class APITest : MonoBehaviour
    {
        public static APITest Instance = null;


        void Start()
        {
            Instance = this;
        }

        public void TestDrawDyke()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "unity_start_point", "817,1760,0" },
                { "unity_end_point", "961,2281,0" }
            };
            ConnectionManager.Instance.SendExecutableAsk("action_management_with_unity", args);
        }

        public void TestDrawDykeWithParams(Vector3 startPoint, Vector3 endPoint)
        {
            string startPointStr = (int)startPoint.x + "," +
                                   (int)(startPoint.z >= 0 ? startPoint.z : startPoint.z * -1) + "," + "0";
            string endPointStr = (int)endPoint.x + "," + (int)(endPoint.z >= 0 ? endPoint.z : endPoint.z * -1) + "," +
                                 "0";
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "unity_start_point", startPointStr },
                { "unity_end_point", endPointStr }
            };
            ConnectionManager.Instance.SendExecutableAsk("action_management_with_unity", args);
        }

        public void TestRemoveDyke()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "dyke_name", "dyke0" }
            };
            ConnectionManager.Instance.SendExecutableAsk("remove_dyke_with_unity", args);
        }

        public void TestSetInTutorial()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.PLAYBACK.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }

        public void TestSetInGame()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.DIKING.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }

        public void TestSetStartPressed()
        {
            Debug.Log("TestSetStartPressed");
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.START.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }

        public void TestSetInFlood()
        {
            Debug.Log("TestSetStartPressed");
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.FLOODING.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }
    }
}