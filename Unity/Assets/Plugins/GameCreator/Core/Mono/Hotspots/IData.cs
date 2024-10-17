using UnityEngine;

namespace GameCreator.Core
{
    [System.Serializable]
    public abstract class IData
    {
        public Hotspot hotspot;
        public IHPMonoBehaviour instance;
        public bool enabled = false;

        public void Setup(Hotspot hotspot, GameObject instance)
        {
            this.hotspot = hotspot;
            this.instance = this.instance.GetComponent<IHPMonoBehaviour>();
        }
    }
}