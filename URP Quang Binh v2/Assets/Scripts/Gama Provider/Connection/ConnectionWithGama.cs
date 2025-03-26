using UnityEngine;
using WebSocketSharp;
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.Json;
using System.Buffers;

public class ConnectionWithGama : MonoBehaviour
{
    protected string ip;
    protected string port;
    private string AgentToSendInfo = "simulation[0].unity_linker[0]";
    protected WebSocket socket;
    protected string MessageSeparator = "|||";

    protected void SendMessageToServer(string message, Action<bool> successCallback)
    {
        socket.SendAsync(message, successCallback);
    }

    public void SendExecutableAsk(string action, Dictionary<string, string> arguments)
    {
        // Build the "args" JSON manually.
        // Create an array for each key-value pair string and then join them.
        string[] argsArray = new string[arguments.Count];
        int idx = 0;
        foreach (var kvp in arguments)
        {
            // Each pair is assembled as "escapedKey:escapedValue"
            argsArray[idx++] = EscapeJson(kvp.Key) + ":" + EscapeJson(kvp.Value);
        }

        // Join the key-value pairs with commas and wrap with braces.
        string argsJson = "{" + string.Join(",", argsArray) + "}";

        // Manually construct the entire JSON string.
        string jsonRaw = "{" +
                         "\"type\":" + EscapeJson("ask") + "," +
                         "\"action\":" + EscapeJson(action) + "," +
                         "\"args\":" + argsJson + "," +
                         "\"agent\":" + EscapeJson(AgentToSendInfo) +
                         "}";

        // Write the complete JSON string in one go.
        var bufferWriter = new ArrayBufferWriter<byte>();
        using (var writer = new Utf8JsonWriter(bufferWriter))
        {
            writer.WriteRawValue(jsonRaw, skipInputValidation: true);
            writer.Flush();
        }

        string jsonStringExpression = Encoding.UTF8.GetString(bufferWriter.WrittenSpan);
        SendMessageToServer(jsonStringExpression, success =>
        {
            if (!success)
            {
                Debug.LogError("ConnectionManager: Failed to send executable expression");
            }
        });
    }

// Custom helper to escape JSON strings without using StringBuilder.
    private static string EscapeJson(string s)
    {
        if (s == null)
        {
            return "\"\"";
        }

        // First, calculate how many extra characters are needed for escaping.
        int extra = 0;
        foreach (char c in s)
        {
            switch (c)
            {
                case '\\':
                case '"':
                case '\b':
                case '\f':
                case '\n':
                case '\r':
                case '\t':
                    extra++;
                    break;
                default:
                    if (c < ' ')
                    {
                        extra += 5; // e.g. \uXXXX (6 total, but 1 for the original char)
                    }

                    break;
            }
        }

        // Allocate a char array large enough to hold the escaped string plus surrounding quotes.
        char[] buffer = new char[s.Length + extra + 2];
        int pos = 0;
        buffer[pos++] = '"';
        foreach (char c in s)
        {
            switch (c)
            {
                case '\\':
                    buffer[pos++] = '\\';
                    buffer[pos++] = '\\';
                    break;
                case '"':
                    buffer[pos++] = '\\';
                    buffer[pos++] = '"';
                    break;
                case '\b':
                    buffer[pos++] = '\\';
                    buffer[pos++] = 'b';
                    break;
                case '\f':
                    buffer[pos++] = '\\';
                    buffer[pos++] = 'f';
                    break;
                case '\n':
                    buffer[pos++] = '\\';
                    buffer[pos++] = 'n';
                    break;
                case '\r':
                    buffer[pos++] = '\\';
                    buffer[pos++] = 'r';
                    break;
                case '\t':
                    buffer[pos++] = '\\';
                    buffer[pos++] = 't';
                    break;
                default:
                    if (c < ' ')
                    {
                        // Write as \uXXXX
                        buffer[pos++] = '\\';
                        buffer[pos++] = 'u';
                        buffer[pos++] = ToHex((c >> 12) & 0xF);
                        buffer[pos++] = ToHex((c >> 8) & 0xF);
                        buffer[pos++] = ToHex((c >> 4) & 0xF);
                        buffer[pos++] = ToHex(c & 0xF);
                    }
                    else
                    {
                        buffer[pos++] = c;
                    }

                    break;
            }
        }

        buffer[pos++] = '"';
        return new string(buffer, 0, pos);
    }

    private static char ToHex(int value)
    {
        return (char)(value < 10 ? value + '0' : value - 10 + 'A');
    }
}