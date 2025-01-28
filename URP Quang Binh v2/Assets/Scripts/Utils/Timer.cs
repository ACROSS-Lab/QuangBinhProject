using UnityEngine;

public class Timer : MonoBehaviour
{
    [Header("Display Settings")] [SerializeField]
    private TMPro.TextMeshProUGUI timerText;

    [SerializeField] private Color startColor = new Color(0, 201, 0, 255);
    [SerializeField] private Color midColor = new Color(255, 218, 0, 255);
    [SerializeField] private Color endColor = new Color(255, 0, 0, 255);

    [Header("Timer settings")] [SerializeField]
    private float timerDuration = 10.0f;

    private bool _timerRunning;
    private float _midTime;
    private float _timeRemaining;

    // ############################################################

    void Start()
    {
        if (PlayerPrefs.GetFloat("TIMER") != 0.0)
        {
            timerDuration = PlayerPrefs.GetFloat("TIMER");
        }
        else
        {
            PlayerPrefs.SetFloat("TIMER", timerDuration);
        }

        _timerRunning = false;
        _timeRemaining = timerDuration;
        _midTime = timerDuration / 2;
        DisplayTime(_timeRemaining - 1);
    }

    void Update()
    {
        if (_timerRunning)
        {
            if (_timeRemaining > 0)
            {
                _timeRemaining -= Time.deltaTime;
                DisplayTime(_timeRemaining);
            }
            else
            {
                _timerRunning = false;
                _timeRemaining = 0;
                SimulationManager.Instance.UpdateGameState(GameState.END);
            }
        }
        else
        {
            _timeRemaining = timerDuration;
        }
    }

    // ############################################################

    private void DisplayTime(float time)
    {
        time += 1;
        float minutes = Mathf.FloorToInt(time / 60);
        float seconds = Mathf.FloorToInt(time % 60);
        if (timerText != null)
        {
            timerText.text = $"{minutes:00}:{seconds:00}";
            timerText.color = time > _midTime
                ? Color.Lerp(midColor, startColor, (time - _midTime) / _midTime)
                : Color.Lerp(endColor, midColor, (time) / _midTime);
        }
    }

    public void Reset()
    {
        _timerRunning = false;
        _timeRemaining = timerDuration;
    }

    // ############################################################

    public void SetTimerDuration(float duration)
    {
        timerDuration = duration;
    }

    public float GetTimerDuration()
    {
        return timerDuration;
    }

    public void SetTimerRunning(bool running)
    {
        _timerRunning = running;
    }

    public bool IsTimerRunning()
    {
        return _timerRunning;
    }
}