using System.Collections;
using UnityEngine;

namespace Gama_Provider.Simulation
{
    public class StatusEffectManager : MonoBehaviour
    {
        public GameObject energizedEffect;

        [SerializeField] private float duration;

        private void Start()
        {
            //StartEnergizedEffect(duration);
        }

        public void StartEnergizedEffect(float customDuration)
        {
            energizedEffect.SetActive(true);

            energizedEffect.GetComponentInChildren<CircularProgressBar>()
                .ActivateCountdown(customDuration);

            StartCoroutine(EndEnergizedEffect(customDuration));
        }

        IEnumerator EndEnergizedEffect(float delay)
        {
            yield return new WaitForSeconds(delay);
            //energizedEffect.SetActive(false);
        }
    }
}