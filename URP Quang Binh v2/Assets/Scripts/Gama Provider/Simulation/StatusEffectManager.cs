using System.Collections;
using UnityEngine;

namespace Gama_Provider.Simulation
{
    public class StatusEffectManager : MonoBehaviour
    {
        public GameObject energizedEffect;

        [SerializeField] private float duration;


        public void UpdateEnergizedEffect(float val)
        {
            energizedEffect.GetComponentInChildren<CircularProgressBar>().updateIndicator(val);

        }
        public void StartEnergizedEffect(float customDuration)
        {
            energizedEffect.SetActive(true);

            energizedEffect.GetComponentInChildren<CircularProgressBar>()
                .ActivateCountdown(customDuration);
            if (energizedEffect.GetComponentInChildren<CircularProgressBar>().isTimer)
                StartCoroutine(EndEnergizedEffect(customDuration));
        }

        IEnumerator EndEnergizedEffect(float delay)
        {
            yield return new WaitForSeconds(delay);
            energizedEffect.SetActive(false);
        }
    }
}