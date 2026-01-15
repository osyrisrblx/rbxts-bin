/// <reference types="@rbxts/testez/globals" />

import { Bin } from "@rbxts/bin";

// Mock helpers
function createDestroyable() {
	const mock = {
		destroyed: false,
		destroy() {
			this.destroyed = true;
		},
	};
	return mock;
}

function createDestroyableUppercase() {
	const mock = {
		destroyed: false,
		Destroy() {
			this.destroyed = true;
		},
	};
	return mock;
}

function createDisconnectable() {
	const mock = {
		disconnected: false,
		disconnect() {
			this.disconnected = true;
		},
	};
	return mock;
}

function createDisconnectableUppercase() {
	const mock = {
		disconnected: false,
		Disconnect() {
			this.disconnected = true;
		},
	};
	return mock;
}

export = () => {
	describe("Bin.new()", () => {
		it("should create a new Bin instance", () => {
			const bin = new Bin();
			expect(bin).to.be.ok();
		});

		it("should start empty", () => {
			const bin = new Bin();
			expect(bin.isEmpty()).to.equal(true);
		});
	});

	describe("Bin.add()", () => {
		it("should add a function to the bin", () => {
			const bin = new Bin();
			const fn = () => {};
			const returned = bin.add(fn);

			expect(returned).to.equal(fn);
			expect(bin.isEmpty()).to.equal(false);
		});

		it("should add an object with destroy() to the bin", () => {
			const bin = new Bin();
			const mock = createDestroyable();
			const returned = bin.add(mock);

			expect(returned).to.equal(mock);
			expect(bin.isEmpty()).to.equal(false);
		});

		it("should add an object with Destroy() to the bin", () => {
			const bin = new Bin();
			const mock = createDestroyableUppercase();
			const returned = bin.add(mock);

			expect(returned).to.equal(mock);
			expect(bin.isEmpty()).to.equal(false);
		});

		it("should add an object with disconnect() to the bin", () => {
			const bin = new Bin();
			const mock = createDisconnectable();
			const returned = bin.add(mock);

			expect(returned).to.equal(mock);
			expect(bin.isEmpty()).to.equal(false);
		});

		it("should add an object with Disconnect() to the bin", () => {
			const bin = new Bin();
			const mock = createDisconnectableUppercase();
			const returned = bin.add(mock);

			expect(returned).to.equal(mock);
			expect(bin.isEmpty()).to.equal(false);
		});

		it("should return the added item for chaining", () => {
			const bin = new Bin();
			const item = { destroy() {} };
			const returned = bin.add(item);

			expect(returned).to.equal(item);
		});

		it("should handle adding multiple items", () => {
			const bin = new Bin();

			bin.add(() => {});
			bin.add(createDestroyable());
			bin.add(createDisconnectable());

			expect(bin.isEmpty()).to.equal(false);
		});
	});

	describe("Bin.destroy()", () => {
		it("should call functions when destroyed", () => {
			const bin = new Bin();
			let called = false;

			bin.add(() => {
				called = true;
			});

			bin.destroy();

			expect(called).to.equal(true);
		});

		it("should call destroy() on objects with lowercase method", () => {
			const bin = new Bin();
			const mock = createDestroyable();

			bin.add(mock);
			bin.destroy();

			expect(mock.destroyed).to.equal(true);
		});

		it("should call Destroy() on objects with uppercase method", () => {
			const bin = new Bin();
			const mock = createDestroyableUppercase();

			bin.add(mock);
			bin.destroy();

			expect(mock.destroyed).to.equal(true);
		});

		it("should call disconnect() on objects with lowercase method", () => {
			const bin = new Bin();
			const mock = createDisconnectable();

			bin.add(mock);
			bin.destroy();

			expect(mock.disconnected).to.equal(true);
		});

		it("should call Disconnect() on objects with uppercase method", () => {
			const bin = new Bin();
			const mock = createDisconnectableUppercase();

			bin.add(mock);
			bin.destroy();

			expect(mock.disconnected).to.equal(true);
		});

		it("should make bin empty after destroy", () => {
			const bin = new Bin();

			bin.add(() => {});
			bin.add(createDestroyable());

			expect(bin.isEmpty()).to.equal(false);

			bin.destroy();

			expect(bin.isEmpty()).to.equal(true);
		});

		it("should handle destroying an empty bin gracefully", () => {
			const bin = new Bin();

			// Should not throw
			bin.destroy();

			expect(bin.isEmpty()).to.equal(true);
		});

		it("should destroy items in FIFO order", () => {
			const bin = new Bin();
			const order: number[] = [];

			bin.add(() => {
				order.push(1);
			});
			bin.add(() => {
				order.push(2);
			});
			bin.add(() => {
				order.push(3);
			});

			bin.destroy();

			expect(order[0]).to.equal(1);
			expect(order[1]).to.equal(2);
			expect(order[2]).to.equal(3);
		});

		it("should handle mixed item types correctly", () => {
			const bin = new Bin();

			let fnCalled = false;
			const destroyMock = createDestroyable();
			const disconnectMock = createDisconnectable();

			bin.add(() => {
				fnCalled = true;
			});
			bin.add(destroyMock);
			bin.add(disconnectMock);

			bin.destroy();

			expect(fnCalled).to.equal(true);
			expect(destroyMock.destroyed).to.equal(true);
			expect(disconnectMock.disconnected).to.equal(true);
		});
	});

	describe("Bin.isEmpty()", () => {
		it("should return true for a new bin", () => {
			const bin = new Bin();
			expect(bin.isEmpty()).to.equal(true);
		});

		it("should return false after adding an item", () => {
			const bin = new Bin();
			bin.add(() => {});
			expect(bin.isEmpty()).to.equal(false);
		});

		it("should return true after destroy", () => {
			const bin = new Bin();
			bin.add(() => {});
			bin.destroy();
			expect(bin.isEmpty()).to.equal(true);
		});
	});

	describe("Bin thread handling", () => {
		it("should add threads to the bin", () => {
			const bin = new Bin();
			const thread = coroutine.create(() => {});
			const returned = bin.add(thread);

			expect(returned).to.equal(thread);
			expect(bin.isEmpty()).to.equal(false);
		});

		it("should cancel threads when destroyed", () => {
			const bin = new Bin();
			let threadCompleted = false;

			const thread = coroutine.create(() => {
				task.wait(10);
				threadCompleted = true;
			});

			task.spawn(thread);
			bin.add(thread);
			bin.destroy();

			task.wait(0.05);
			expect(threadCompleted).to.equal(false);
		});
	});

	describe("Bin edge cases", () => {
		it("should allow reuse after destroy", () => {
			const bin = new Bin();

			let called1 = false;
			bin.add(() => {
				called1 = true;
			});
			bin.destroy();

			expect(called1).to.equal(true);
			expect(bin.isEmpty()).to.equal(true);

			// Add new items after destroy
			let called2 = false;
			bin.add(() => {
				called2 = true;
			});

			expect(bin.isEmpty()).to.equal(false);

			bin.destroy();

			expect(called2).to.equal(true);
			expect(bin.isEmpty()).to.equal(true);
		});

		it("should handle destroy being called multiple times", () => {
			const bin = new Bin();
			let callCount = 0;

			bin.add(() => {
				callCount++;
			});

			bin.destroy();
			bin.destroy();
			bin.destroy();

			// Should only be called once since bin is empty after first destroy
			expect(callCount).to.equal(1);
		});

		it("should handle large number of items", () => {
			const bin = new Bin();
			let callCount = 0;

			for (let i = 0; i < 1000; i++) {
				bin.add(() => {
					callCount++;
				});
			}

			bin.destroy();

			expect(callCount).to.equal(1000);
			expect(bin.isEmpty()).to.equal(true);
		});
	});
};
