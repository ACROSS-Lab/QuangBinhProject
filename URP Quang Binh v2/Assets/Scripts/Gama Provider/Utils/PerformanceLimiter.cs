using UnityEngine;
using Unity.Jobs.LowLevel.Unsafe;

public class PerformanceLimiter : MonoBehaviour
{
    [Header("Framerate Settings")]
    [Tooltip("Nombre maximum de FPS (ex : 60)")]
    public int targetFPS = 60;

    [Header("Job System Settings")]
    [Tooltip("Nombre maximum de workers pour le Job System (ex : 2)")]
    public int maxJobWorkers = 1;

    void Awake()
    {
        Application.targetFrameRate = 60; 
        // Screen.SetResolution(targetWidth, targetHeight, true);
        Screen.SetResolution(1920, 1080, false);
        // Désactive le VSync (sinon il écrase le targetFrameRate)
        //QualitySettings.vSyncCount = 1;

        // Fixe le framerate
        //Application.targetFrameRate = targetFPS;

        // Limite le nombre de threads du Job System
        if (maxJobWorkers > 0) 
        {
            JobsUtility.JobWorkerCount = maxJobWorkers;
        }

        Debug.Log($"[PerformanceLimiter] FPS limité à {targetFPS}, Job Workers = {JobsUtility.JobWorkerCount}");
    } 
}   