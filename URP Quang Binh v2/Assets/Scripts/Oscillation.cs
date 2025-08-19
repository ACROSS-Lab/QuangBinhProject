using UnityEngine;
using DG.Tweening; // obligatoire pour utiliser DOTween

public class Oscillation : MonoBehaviour
{
    [SerializeField] private float amplitude = 1f; // distance du mouvement vertical
    [SerializeField] private float duration = 1f;  // durée pour un aller simple

    private void Start()
    {
        // Position de départ
        float startY = transform.position.y;

        // Mouvement vertical
        transform.DOMoveY(startY + amplitude, duration)
                 .SetEase(Ease.InOutQuart)     // mouvement fluide (sinusoïdal)
                 .SetLoops(-1, LoopType.Yoyo); // -1 = infini, Yoyo = aller-retour
    }
}