using UnityEngine;
using UnityEngine.UI;

namespace Gama_Provider.Simulation
{
    public class CircularProgressBar : MonoBehaviour
    {
        private bool _isActive;

        private float _indicatorTimer;
        private float _maxIndicatorTimer;

        private Image _radialProgressBar;

        private void Awake()
        {
            _radialProgressBar = GetComponent<Image>();
        }

        private void Update()
        {
            if (_isActive)
            {
                _indicatorTimer -= Time.deltaTime;

                var currentRatio = _indicatorTimer / _maxIndicatorTimer;

                Debug.Log("Indicator time: " + _indicatorTimer);
                Debug.Log("Max indicator time: " + _maxIndicatorTimer);

                switch (currentRatio)
                {
                    case > 0.75f:
                        _radialProgressBar.color = new Color(6 / 255f, 156 / 255f, 86 / 255f);
                        break;

                    case >= 0.25f and <= 0.75f:
                        _radialProgressBar.color = new Color(255 / 255f, 152 / 255f, 14 / 255f);
                        break;

                    case < 0.25f:
                        _radialProgressBar.color = new Color(211 / 255f, 33 / 255f, 44 / 255f);
                        break;
                }

                _radialProgressBar.fillAmount = _indicatorTimer / _maxIndicatorTimer;
                Debug.Log("_radialProgressBar.fillAmount: " + _radialProgressBar.fillAmount);

                if (_indicatorTimer / _maxIndicatorTimer <= 0.5f)
                {
                }

                if (_indicatorTimer <= 0)
                {
                    StopCountdown();
                }
            }
        }

        public void ActivateCountdown(float countdownTime)
        {
            _isActive = true;
            _maxIndicatorTimer = countdownTime;
            _indicatorTimer = _maxIndicatorTimer;
        }

        private void StopCountdown()
        {
            _isActive = false;
        }
    }
}