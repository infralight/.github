const core = require("@actions/core");
const exec = require("@actions/exec");
const semverInc = require("semver/functions/inc");

async function execGitCommand(args) {
    let output = "";
    const options = {};
    options.listeners = {
        stdout: (data) => {
            output += data.toString();
        },
    };
    await exec.exec("git", args, options);
    return output.trim();
}

async function run() {
    try {
        const vRegex = new RegExp("^v");

        // Get the starting version for the component, if received, and remove
        // the "v" prefix if it was accidentally included.
        let startingVersion = core.getInput("starting-version");

        if (!startingVersion) {
            startingVersion = "0.0.0";
        } else if (vRegex.test(startingVersion)) {
            startingVersion = startingVersion.replace(vRegex, "");
        }

        console.log(`Starting version is ${startingVersion}`);

        // Get the component name and path
        const componentName = core.getInput("component-name", {
            required: true,
        });

        const pRegex = new RegExp("/$");

        let componentPath = core.getInput("component-path", { required: true });
        if (!pRegex.test(componentPath)) {
            componentPath += "/";
        }

        const componentTagRegex = new RegExp(`${componentName}-v(.+)$`);

        console.log(`Component is ${componentName} at ${componentPath}`);

        // Get the list of commits that affected the component
        const log = await execGitCommand([
            "log",
            "--format=%H",
            "--",
            componentPath,
        ]);

        let previousVersion = startingVersion;
        let bump = 0;
        let hadBumpTags = false;

        for (const commit of log.split("\n")) {
            try {
                // See if this commit has a tag for this component. If it does,
                // then this is the previous version of the component.
                const tag = await execGitCommand([
                    "describe",
                    "--tags",
                    "--exact-match",
                    commit,
                ]);

                const match = componentTagRegex.exec(tag);
                if (match) {
                    previousVersion = match[1];
                    break;
                }
            } catch (error) {
                // This commit doesn't have an exact-match tag, meaning it's part
                // of the new version. Read its commit message to verify what
                // part of the version number we need to bump (major/minor/patch).
                const message = await execGitCommand([
                    "log",
                    "--format=%B",
                    "-n",
                    "1",
                    commit,
                ]);

                let commitBump = 0;
                if (message.includes("#patch")) {
                    hadBumpTags = true;
                    commitBump = 1;
                } else if (message.includes("#minor")) {
                    hadBumpTags = true;
                    commitBump = 2;
                } else if (message.includes("#major")) {
                    hadBumpTags = true;
                    commitBump = 3;
                } else {
                    commitBump = 2;
                }

                if (commitBump > bump) bump = commitBump;
            }
        }

        const bumpStr = !hadBumpTags
            ? "minor"
            : bump === 3
              ? "major"
              : bump === 2
                ? "minor"
                : "patch";
        console.log(`Bumping "${bumpStr}" version component`);

        const version = semverInc(previousVersion, bumpStr);

        if (version === null) {
            core.setFailed(
                `Failed bumping "${bumpStr}" component of version ${previousVersion}, got null`,
            );
            return;
        }

        console.log(`Bumped ${previousVersion} to ${version}`);

        const tag = `${componentName}-v${version}`;

        console.log(`New tag is ${tag}`);

        // Create and push the tag
        await execGitCommand(["tag", "-a", tag]);
        await execGitCommand(["push", "origin", tag]);

        core.setOutput("tag", tag);
        core.setOutput("version", version);
    } catch (err) {
        core.setFailed(err.message);
    }
}

if (require.main === module) {
    run();
}

module.exports = run;
