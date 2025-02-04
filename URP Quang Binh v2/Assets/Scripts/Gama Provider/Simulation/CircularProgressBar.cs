using UnityEngine;
using UnityEngine.UI;

namespace Gama_Provider.Simulation
{
    public class CircularProgressBar : MonoBehaviour
    {
        private bool _isActive;

        private float _indicator;
        private float _maxIndicator;
        public bool isTimer = true;
        private Image _radialProgressBar;

        private void Awake()
        {
            _radialProgressBar = GetComponent<Image>();
        }


        private void Update()
        {
            Debug.Log("_isActive: " + _isActive);

            if (_isActive)
            {
                if (isTimer) 
                    _indicator -= Time.deltaTime;


                Debug.Log("_indicator: " + _indicator);
                var currentRatio = _indicator / _maxIndicator;

               // Debug.Log("Indicator time: " + _indicator);
               // Debug.Log("Max indicator time: " + _maxIndicator);

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

                _radialProgressBar.fillAmount = currentRatio;
              //  Debug.Log("_radialProgressBar.fillAmount: " + _radialProgressBar.fillAmount);

               
                if (_indicator <= 0)
                {
                    StopCountdown();
                }
            }
        }

        public void updateIndicator(float newVal)
        {
            _indicator = newVal;
            Debug.Log("updateIndicator _indicator: " + _indicator);
        }
        public void ActivateCountdown(float countdownTime)
        {
            _isActive = true;
            _maxIndicator = countdownTime;
            _indicator = _maxIndicator;
        }

        private void StopCountdown()
        {
            _isActive = false;
        }
    }
}