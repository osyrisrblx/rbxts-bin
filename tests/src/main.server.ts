/// <reference types="@rbxts/testez/globals" />

import TestEZ from "@rbxts/testez";
import { ServerScriptService } from "@rbxts/services";

const results = TestEZ.TestBootstrap.run([ServerScriptService.FindFirstChild("tests") as Folder]);

if (results.errors.size() > 0 || results.failureCount > 0) {
	error("Tests failed!");
}
