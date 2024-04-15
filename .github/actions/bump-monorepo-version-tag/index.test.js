const mock = require("jest-mock");
const core = require("@actions/core");
const exec = require("@actions/exec");

// Mock the @actions/core and @actions/exec modules used by our GitHub Action
jest.mock("@actions/core");
jest.mock("@actions/exec");

const run = require("./index");

// To test our action, we'll mock a repository with two components, "component1"
// and "component2". Our action will be bumping the version of "component1".
//
// The following scenarios will be tested:
// 1. starting-version has not been provided, and a previous tag for component1
//    does not exist. We expect the new tag to be component1-v0.1.0.
// 2. starting-version has not been provided, and a previous tag does exist
//    (component1-v1.35.0). We expect the new tag to be component1-v2.0.0.
// 3. starting-version has been provided (1.35.0), and a previous tag does not
//    exist. We expect the new tag to be component1-v1.35.1.
// 4. starting-version has been provided (1.35.0), and a previous tag does exist
//    (component1-v2.9.0). We expect the new tag to be component1-v2.10.0.

describe("Test GitHub Action", () => {
    // Reset the mocks before each test
    beforeEach(() => {
        jest.resetModules();
        core.getInput = jest.fn();
        core.setOutput = jest.fn();
        core.setFailed = jest.fn();
        exec.exec = mock.fn();
    });

    test("scenario-1", async () => {
        core.getInput
            .mockReturnValueOnce("") // Mock starting-version input
            .mockReturnValueOnce("components/component1/"); // Mock component-path input

        // Mock results for the git commands that will be executed by the action.
        // There'll be a command to list all commits for the component, then
        // for each of those commits there'll be a command to get its tag (which
        // should fail in this scenario), and a log command to get its commit
        // message.
        exec.exec.mockImplementation((cmd, args, options) => {
            if (cmd === "git") {
                if (args[0] === "log" && args[1] === "--format=%H") {
                    options.listeners.stdout(Buffer.from("0002\n0001"));
                    return Promise.resolve(0);
                } else if (args[0] === "describe") {
                    throw new Error(
                        "fatal: No names found, cannot describe anything.",
                    );
                } else if (
                    args[0] === "log" &&
                    args[1] === "--format=%B" &&
                    args[4] === "0002"
                ) {
                    options.listeners.stdout(
                        Buffer.from("Fix something #patch"),
                    );
                    return Promise.resolve(0);
                } else if (
                    args[0] === "log" &&
                    args[1] === "--format=%B" &&
                    args[4] === "0001"
                ) {
                    options.listeners.stdout(
                        Buffer.from("Introduce feature #minor"),
                    );
                    return Promise.resolve(0);
                }
            }

            return Promise.resolve(0);
        });

        await run();

        expect(core.setOutput).toHaveBeenCalledWith(
            "tag",
            "components/component1/v0.1.0",
        );
        expect(core.setOutput).toHaveBeenCalledWith("version", "0.1.0");
    });

    test("scenario-2", async () => {
        core.getInput
            .mockReturnValueOnce("") // Mock starting-version input
            .mockReturnValueOnce("components/component1/"); // Mock component-path input

        exec.exec.mockImplementation((cmd, args, options) => {
            if (cmd === "git") {
                if (args[0] === "log" && args[1] === "--format=%H") {
                    options.listeners.stdout(Buffer.from("0002\n0001"));
                    return Promise.resolve(0);
                } else if (args[0] === "describe" && args[3] == "0002") {
                    throw new Error(
                        "fatal: No names found, cannot describe anything.",
                    );
                } else if (args[0] === "describe" && args[3] == "0001") {
                    options.listeners.stdout(
                        Buffer.from("components/component1/v1.35.0"),
                    );
                    return Promise.resolve(0);
                } else if (
                    args[0] === "log" &&
                    args[1] === "--format=%B" &&
                    args[4] === "0002"
                ) {
                    options.listeners.stdout(
                        Buffer.from("Change everything #major"),
                    );
                    return Promise.resolve(0);
                }
            }

            return Promise.resolve(0);
        });

        await run();

        expect(core.setOutput).toHaveBeenCalledWith(
            "tag",
            "components/component1/v2.0.0",
        );
        expect(core.setOutput).toHaveBeenCalledWith("version", "2.0.0");
    });

    test("scenario-3", async () => {
        core.getInput
            .mockReturnValueOnce("v1.35.0") // Mock starting-version input
            .mockReturnValueOnce("components/component1"); // Mock component-path input

        // In both the starting-version and component-path we have provided the
        // input incorrectly: starting-version with a "v" prefix which should not
        // be provided, and component-path without a trailing slash which should
        // be provided. We're checking that the action properly handles this.

        exec.exec.mockImplementation((cmd, args, options) => {
            if (cmd === "git") {
                if (args[0] === "log" && args[1] === "--format=%H") {
                    options.listeners.stdout(Buffer.from("0002\n0001"));
                    return Promise.resolve(0);
                } else if (args[0] === "describe") {
                    throw new Error(
                        "fatal: No names found, cannot describe anything.",
                    );
                } else if (
                    args[0] === "log" &&
                    args[1] === "--format=%B" &&
                    args[4] === "0002"
                ) {
                    options.listeners.stdout(
                        Buffer.from("Fix something #patch"),
                    );
                    return Promise.resolve(0);
                } else if (
                    args[0] === "log" &&
                    args[1] === "--format=%B" &&
                    args[4] === "0001"
                ) {
                    options.listeners.stdout(
                        Buffer.from("Fix something else #patch"),
                    );
                    return Promise.resolve(0);
                }
            }

            return Promise.resolve(0);
        });

        await run();

        expect(core.setOutput).toHaveBeenCalledWith(
            "tag",
            "components/component1/v1.35.1",
        );
        expect(core.setOutput).toHaveBeenCalledWith("version", "1.35.1");
    });

    test("scenario-4", async () => {
        core.getInput
            .mockReturnValueOnce("v1.35.0") // Mock starting-version input
            .mockReturnValueOnce("components/component1"); // Mock component-path input

        // In both the starting-version and component-path we have provided the
        // input incorrectly: starting-version with a "v" prefix which should not
        // be provided, and component-path without a trailing slash which should
        // be provided. We're checking that the action properly handles this.

        exec.exec.mockImplementation((cmd, args, options) => {
            if (cmd === "git") {
                if (args[0] === "log" && args[1] === "--format=%H") {
                    options.listeners.stdout(Buffer.from("0002\n0001"));
                    return Promise.resolve(0);
                } else if (args[0] === "describe" && args[3] == "0002") {
                    throw new Error(
                        "fatal: No names found, cannot describe anything.",
                    );
                } else if (args[0] === "describe" && args[3] == "0001") {
                    options.listeners.stdout(
                        Buffer.from("components/component1/v2.9.0"),
                    );
                    return Promise.resolve(0);
                } else if (
                    args[0] === "log" &&
                    args[1] === "--format=%B" &&
                    args[4] === "0002"
                ) {
                    options.listeners.stdout(
                        Buffer.from("Do something, no hashtag"),
                    );
                    return Promise.resolve(0);
                }
            }

            return Promise.resolve(0);
        });

        await run();

        expect(core.setOutput).toHaveBeenCalledWith(
            "tag",
            "components/component1/v2.10.0",
        );
        expect(core.setOutput).toHaveBeenCalledWith("version", "2.10.0");
    });
});
