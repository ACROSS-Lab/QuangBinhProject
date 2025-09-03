using UnityEngine;
using UnityEngine.UI;

public class BlinkingFrame : MonoBehaviour
{
    public Image frame;       // l’Image servant de cadre
    public float speed = 2f;  // vitesse du clignotement

    private Color baseColor;

    void Start()
    {
        if (frame == null)
            frame = GetComponent<Image>();

        baseColor = frame.color;
    }

    void Update()
    {
        // Alpha qui varie entre 0 et 1 avec une sinusoïde
        float alpha = (Mathf.Sin(Time.time * speed) + 1f) / 2f;
        frame.color = new Color(baseColor.r, baseColor.g, baseColor.b, alpha);
    }
}