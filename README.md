# `@rbxts/bin`

A super simple alternative to Maid.


### `Bin.Item`
```TS
type Bin.Item =
	(() => unknown) // any function
	| RBXScriptConnection // an event connection
	| { destroy(): void } // object with destroy() or Destroy()
	| { Destroy(): void }; // i.e. Roblox Instances!
```

### `Bin.add`
```TS
public add<T extends Bin.Item>(item: T): T;
```

Adds the item into the Bin, will return the item you passed in.

The returned value is useful for instances:
```TS
const part = this.bin.add(new Instance("Part"));
this.bin.add(part.Touched.Connect(() => print("Touched!"));

// later..

// both `part` and the connection are cleaned up!
this.bin.destroy();
```

### `Bin.destroy`
```TS
public destroy(): void;
```
Destroys all items currently in the Bin:
- Functions will be called
- RBXScriptConnections will be disconnected
- Objects will be `.destroy()`-ed
