export namespace Bin {
	export type Item = (() => unknown) | RBXScriptConnection | thread | { destroy(): void } | { Destroy(): void };
}

type Node = { next?: Node; item: Bin.Item };

/**
 * Tracks connections, instances, functions, threads, and objects to be later destroyed.
 */
export class Bin {
	private head: Node | undefined;
	private tail: Node | undefined;

	/**
	 * Adds an item into the Bin. This can be a:
	 * - `() => unknown`
	 * - RBXScriptConnection
	 * - thread
	 * - Object with `.destroy()` or `.Destroy()`
	 */
	public add<T extends Bin.Item>(item: T): T {
		const node: Node = { item };
		this.head ??= node;
		if (this.tail) this.tail.next = node;
		this.tail = node;
		return item;
	}

	/**
	 * Destroys all items currently in the Bin:
	 * - Functions will be called
	 * - RBXScriptConnections will be disconnected
	 * - threads will be `task.cancel()`-ed
	 * - Objects will be `.destroy()`-ed
	 */
	public destroy(): void {
		while (this.head) {
			const item = this.head.item;
			if (typeIs(item, "function")) {
				item();
			} else if (typeIs(item, "RBXScriptConnection")) {
				item.Disconnect();
			} else if (typeIs(item, "thread")) {
				task.cancel(item);
			} else if ("destroy" in item) {
				item.destroy();
			} else if ("Destroy" in item) {
				item.Destroy();
			}

			this.head = this.head.next;
		}

		// list is now empty, so we can clear the tail
		this.tail = undefined;
	}

	/**
	 * Checks whether the Bin is empty.
	 */
	public isEmpty(): boolean {
		return this.head === undefined;
	}
}
