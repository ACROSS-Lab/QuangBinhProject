namespace GameCreator.Core
{
	using System.Collections;
	using System.Collections.Generic;
	using UnityEngine;

	[AddComponentMenu("")]
	public class HPCursor : IHPMonoBehaviour
	{
		[System.Serializable]
		public class Data : IData
		{
			public Texture2D mouseOverCursor = null;
			public Vector2 cursorPosition = Vector2.zero;
		}
		
		public Data data => this._data as Data;

		// OVERRIDE METHODS: ----------------------------------------------------------------------

		public override void Initialize()
		{
			if (!this._data.enabled) return;
		}

		// HOVER CURSOR: --------------------------------------------------------------------------

		public override void HotspotMouseEnter()
		{
            if (this._data.enabled && this.data.mouseOverCursor != null)
			{
				Cursor.SetCursor(this.data.mouseOverCursor, this.data.cursorPosition, CursorMode.Auto);
			}
		}

		public override void HotspotMouseExit()
		{
            if (this._data.enabled && this.data.mouseOverCursor != null)
			{
				Cursor.SetCursor(null, Vector2.zero, CursorMode.Auto);
			}
		}

        public override void HotspotMouseOver()
        {
            if (this._data.enabled && this.data.mouseOverCursor != null)
            {
                if (this.IsWithinConstrainedRadius()) this.HotspotMouseEnter();
                else this.HotspotMouseExit();
            }
        }
	}
}