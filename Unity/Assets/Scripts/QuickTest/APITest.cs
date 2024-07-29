using System.Collections.Generic;
using UnityEngine;

namespace QuickTest
{
    public class APITest : MonoBehaviour
    {

        public void TestDrawDyke()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                {"unity_start_point", "817,1760,0"},
                {"unity_end_point", "961,2281,0"}
                //{"unity_start_point", "1620.6614431035457,3153.6614752123714,0"},
                //{"unity_end_point", "1781.8321943514122,3297.009724085661,0.0"}
            };
            ConnectionManager.Instance.SendExecutableAsk("action_management_with_unity", args);
        }
        
        public void TestUpdateScore()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "diff_value", "1" }
            };
            ConnectionManager.Instance.SendExecutableAsk("update_score", args);
        }

        public void TestUpdateBudget()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "diff_value", "-1" }
            };
            ConnectionManager.Instance.SendExecutableAsk("update_budget", args);
        }

        public void TestBuildDyke()
        {
            TestUpdateBudget();
            TestUpdateScore();
        }
        
        public void TestDrawDykeWithParams(Vector3 startPoint, Vector3 endPoint)
        {
            string startPointStr = startPoint.x + "," + (startPoint.z >= 0 ? startPoint.z : startPoint.z * -1) + "," + "0";
            string endPointStr = endPoint.x + "," + (endPoint.z >= 0 ? endPoint.z : endPoint * -1) + "," + "0";
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                {"unity_start_point", startPointStr},
                {"unity_end_point", endPointStr}
                //{"unity_start_point", "1620.6614431035457,3153.6614752123714,0"},
                //{"unity_end_point", "1781.8321943514122,3297.009724085661,0.0"}
            };
            ConnectionManager.Instance.SendExecutableAsk("action_management_with_unity", args);
        }
    }
}