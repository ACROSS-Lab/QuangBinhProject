namespace GameCreator.Core
{
	using System.Collections;
	using System.Collections.Generic;
	using UnityEngine;
    using GameCreator.Core.Hooks;

	public abstract class IHPMonoBehaviour : MonoBehaviour
	{
		// PROPERTIES: ----------------------------------------------------------------------------

		protected IData _data;

		// PUBLIC METHODS: ------------------------------------------------------------------------

		public static IData Create<THotspot>(Hotspot hotspot, IData data) where THotspot : IHPMonoBehaviour
		{
			GameObject instance = new GameObject(typeof(THotspot).ToString());
			instance.transform.SetParent(hotspot.transform, false);

			THotspot component = instance.AddComponent<THotspot>();
			component._data = data;
			component.ConfigureData(hotspot, instance);
			component.Initialize();
			return component._data;
		}

		private void ConfigureData(Hotspot hotspot, GameObject instance)
		{
			this._data.hotspot = hotspot;
			this._data.instance = instance.GetComponent<IHPMonoBehaviour>();
		}

		// ABSTRACT & VIRTUAL METHODS: ------------------------------------------------------------

		public abstract void Initialize();

		public virtual void HotspotMouseEnter() {}
		public virtual void HotspotMouseExit()  {}
        public virtual void HotspotMouseOver()  {}

        // PROTECTED METHODS: ---------------------------------------------------------------------

        protected bool IsWithinConstrainedRadius()
        {
            if (this._data.hotspot.trigger == null) return true;
            if (!this._data.hotspot.trigger.minDistance) return true;
            if (HookPlayer.Instance == null) return false;

            float distance = Vector3.Distance(
                HookPlayer.Instance.transform.position,
                transform.position
            );

            return (distance <= this._data.hotspot.trigger.minDistanceToPlayer);
        }
	}
}