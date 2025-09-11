using System.Collections;
using UnityEngine;
using TMPro;

namespace Gama_Provider.Simulation
{
    public class StatusEffectManager : MonoBehaviour
    {
        public GameObject energizedEffect;
        public TextMeshProUGUI value = null;

        [SerializeField] private float duration;


        public void UpdateEnergizedEffect(float val)
        {
            energizedEffect.GetComponentInChildren<CircularProgressBar>().updateIndicator(val);
            if (value != null)
            {
                value.SetText("" + ((int) val));
            }
        }
        public void StartEnergizedEffect(float customDuration, bool isTimer)
        {
            energizedEffect.SetActive(true);

            CircularProgressBar c = energizedEffect.GetComponentInChildren<CircularProgressBar>();
            c.isTimer = isTimer;
            c.value = value;
            c.ActivateCountdown(customDuration);

            if (c.isTimer)
                StartCoroutine(EndEnergizedEffect(customDuration));
        }

        public void StartEnergizedEffect(float customDuration)
        {
            energizedEffect.SetActive(true);

            CircularProgressBar c = energizedEffect.GetComponentInChildren<CircularProgressBar>();
            c.ActivateCountdown(customDuration);

            if (c.isTimer)
                StartCoroutine(EndEnergizedEffect(customDuration));
        }

        IEnumerator EndEnergizedEffect(float delay)
        {
            yield return new WaitForSeconds(delay);
            energizedEffect.SetActive(false);
        }
    }
}