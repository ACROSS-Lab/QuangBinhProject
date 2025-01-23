using System.Net;

public static class StaticInformation
{
    public static string endOfGame { get; set; }
    private static string connectionId;

    public static string getId() {

        if (string.IsNullOrEmpty(connectionId))
        {
            string hostName = Dns.GetHostName(); // Retrieve the Name of HOST
            try
            {

                IPAddress[] addresses = Dns.GetHostEntry(hostName).AddressList;
                string myIP = "127.0.0.1";
                foreach (IPAddress a in addresses)
                {
                    if (a.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
                    {
                        myIP = a.ToString();
                        break;
                    }
                }
                
                
                string lastIP = myIP.Contains(".") ? myIP.Split(".")[3] : "0";
                connectionId = "Player_" + lastIP;// + lastIP;
            } catch
            {
                connectionId = hostName;
            }
           
        }
        return connectionId;
    }
}