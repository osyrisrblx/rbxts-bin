export namespace Bin {
	export type Item = (() => unknown) | RBXScriptConnection | { destroy(): void } | { Destroy(): void };
	export type Node = { next?: Bin.Node; item: Bin.Item };
}

/**
 * Tracks connections, instances, functions, and objects to be later destroyed.
 */
export class Bin {
	private head: Bin.Node | undefined;
	private tail: Bin.Node | undefined;

	/**
	 * Adds an item into the Bin. This can be a:
	 * - `() => unknown`
	 * - RBXScriptConnection
	 * - Object with `.destroy()` or `.Destroy()`
	 */
	public add<T extends Bin.Item>(item: T): T {
		const node: Bin.Node = { item };
		this.head ??= node;
		if (this.tail) this.tail.next = node;
		this.tail = node;
		return item;
	}

	public isEmpty(): boolean {
		return this.head !== undefined;
	}

	/**
	 * Destroys all items currently in the Bin:
	 * - Functions will be called
	 * - RBXScriptConnections will be disconnected
	 * - Objects will be `.destroy()`-ed
	 */
	public destroy(): void {
		while (this.head) {
			const item = this.head.item;
			if (typeIs(item, "function")) {
				item();
			} else if (typeIs(item, "RBXScriptConnection")) {
				item.Disconnect();
			} else if ("destroy" in item) {
				item.destroy();
			} else if ("Destroy" in item) {
				item.Destroy();
			}
			this.head = this.head.next;
		}
	}
}
