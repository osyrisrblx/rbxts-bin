export namespace Bin {
	export type Item = (() => unknown) | RBXScriptConnection | { destroy(): void } | { Destroy(): void };
}

/**
 * Tracks connections, instances, functions, and objects to be later destroyed.
 */
export class Bin {
	private items = new Array<Bin.Item>();

	/**
	 * Adds an item into the Bin. This can be a:
	 * - `() => unknown`
	 * - RBXScriptConnection
	 * - Object with `.destroy()` or `.Destroy()`
	 */
	public add<T extends Bin.Item>(item: T): T {
		this.items.push(item);
		return item;
	}

	/**
	 * Destroys all items currently in the Bin:
	 * - Functions will be called
	 * - RBXScriptConnections will be disconnected
	 * - Objects will be `.destroy()`-ed
	 */
	public destroy(): void {
		const items = this.items;
		this.items = [];
		for (const item of items) {
			if (typeIs(item, "function")) {
				item();
			} else if (typeIs(item, "RBXScriptConnection")) {
				item.Disconnect();
			} else if ("destroy" in item) {
				item.destroy();
			} else if ("Destroy" in item) {
				item.Destroy();
			}
		}
	}
}
