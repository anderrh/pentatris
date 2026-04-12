"""Module extension to download hermetic RGBDS and Node.js toolchains."""

# ---------------------------------------------------------------------------
# RGBDS v1.0.0  – Game Boy assembler / linker / fixer
# ---------------------------------------------------------------------------
_RGBDS_VERSION = "1.0.0"
_RGBDS_URLS = {
    "linux-x86_64": {
        "url": "https://github.com/gbdev/rgbds/releases/download/v{v}/rgbds-linux-x86_64.tar.xz".format(v = _RGBDS_VERSION),
        "sha256": "a958b0993234a7a8d9bbf3e37b1e0fb41078f4751726b3d70a6b2712c399fa0a",
    },
    "macos": {
        "url": "https://github.com/gbdev/rgbds/releases/download/v{v}/rgbds-macos.zip".format(v = _RGBDS_VERSION),
        "sha256": "bf978c1e0dc2332141eb3b9435d8bd9e2e9a16dad574a99b68e836fc7a640722",
    },
}

_RGBDS_BUILD = """\
package(default_visibility = ["//visibility:public"])

exports_files(["rgbasm", "rgblink", "rgbfix", "rgbgfx"])
"""

# ---------------------------------------------------------------------------
# Node.js v18.20.8  – JavaScript runtime for test runner
# ---------------------------------------------------------------------------
_NODE_VERSION = "18.20.8"
_NODE_URLS = {
    "linux-x64": {
        "url": "https://nodejs.org/dist/v{v}/node-v{v}-linux-x64.tar.xz".format(v = _NODE_VERSION),
        "sha256": "5467ee62d6af1411d46b6a10e3fb5cacc92734dbcef465fea14e7b90993001c9",
        "strip_prefix": "node-v{v}-linux-x64".format(v = _NODE_VERSION),
    },
    "darwin-x64": {
        "url": "https://nodejs.org/dist/v{v}/node-v{v}-darwin-x64.tar.gz".format(v = _NODE_VERSION),
        "sha256": "ed2554677188f4afc0d050ecd8bd56effb2572d6518f8da6d40321ede6698509",
        "strip_prefix": "node-v{v}-darwin-x64".format(v = _NODE_VERSION),
    },
    "darwin-arm64": {
        "url": "https://nodejs.org/dist/v{v}/node-v{v}-darwin-arm64.tar.gz".format(v = _NODE_VERSION),
        "sha256": "bae4965d29d29bd32f96364eefbe3bca576a03e917ddbb70b9330d75f2cacd76",
        "strip_prefix": "node-v{v}-darwin-arm64".format(v = _NODE_VERSION),
    },
}

_NODE_BUILD = """\
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "node",
    srcs = ["bin/node"],
)
"""

# ---------------------------------------------------------------------------
# Module extension implementation
# ---------------------------------------------------------------------------

def _rgbds_repo(ctx):
    """Repository rule that downloads RGBDS for the host platform."""
    os_name = ctx.os.name.lower()
    arch = ctx.os.arch

    if "linux" in os_name:
        info = _RGBDS_URLS["linux-x86_64"]
    elif "mac" in os_name or "darwin" in os_name:
        info = _RGBDS_URLS["macos"]
    else:
        fail("Unsupported OS for RGBDS: " + os_name)

    ctx.download_and_extract(
        url = info["url"],
        sha256 = info["sha256"],
    )
    ctx.file("BUILD.bazel", _RGBDS_BUILD)

rgbds_repository = repository_rule(
    implementation = _rgbds_repo,
)

def _nodejs_repo(ctx):
    """Repository rule that downloads Node.js for the host platform."""
    os_name = ctx.os.name.lower()
    arch = ctx.os.arch

    if "linux" in os_name:
        info = _NODE_URLS["linux-x64"]
    elif "mac" in os_name or "darwin" in os_name:
        if "aarch64" in arch or "arm64" in arch:
            info = _NODE_URLS["darwin-arm64"]
        else:
            info = _NODE_URLS["darwin-x64"]
    else:
        fail("Unsupported OS for Node.js: " + os_name)

    ctx.download_and_extract(
        url = info["url"],
        sha256 = info["sha256"],
        stripPrefix = info["strip_prefix"],
    )
    ctx.file("BUILD.bazel", _NODE_BUILD)

nodejs_repository = repository_rule(
    implementation = _nodejs_repo,
)

def _toolchains_impl(module_ctx):
    rgbds_repository(name = "rgbds")
    nodejs_repository(name = "nodejs")

toolchains = module_extension(
    implementation = _toolchains_impl,
)
