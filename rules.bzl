# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""A repository rule for integrating the Android NDK."""

load(":ndk_versions.bzl", "NDK_VERSIONS")

def _android_ndk_repository_impl(ctx):
    """Install the Android NDK files.

    Args:
        ctx: An implementation context.

    Returns:
        A final dict of configuration attributes and values.
    """
    version = ctx.attr.version

    if version == None:
        version = "latest"

    if version == "latest":
        version = NDK_VERSIONS[NDK_VERSIONS.keys()[0]]
    ndk_url = "https://dl.google.com/android/repository/android-ndk-{}-{}.zip"

    if ctx.os.name == "linux":
        osname = "linux"
        sha256 = NDK_VERSIONS[version].sha256_linux
    elif ctx.os.name == "mac os x":
        # Note: darwin-x86_64 does indeed contain fat binaries with arm64 slices, too.
        osname = "darwin"
        sha256 = NDK_VERSIONS[version].sha256_darwin
    elif ctx.os.name.startswith("windows"):
        osname = "windows"
        sha256 = NDK_VERSIONS[version].sha256_windows
    else:
        fail("Unsupported operating system: " + ctx.os.name)

    ctx.report_progress("Downloading Android NDK version {}".format(version))
    ctx.download_and_extract(
        url = ndk_url.format(version, osname),
        sha256 =sha256,
        strip_prefix = "android-ndk-{}".format(version),
    )

    is_windows = False
    executable_extension = ""
    if ctx.os.name == "linux":
        clang_directory = "toolchains/llvm/prebuilt/linux-x86_64"
    elif ctx.os.name == "mac os x":
        # Note: darwin-x86_64 does indeed contain fat binaries with arm64 slices, too.
        clang_directory = "toolchains/llvm/prebuilt/darwin-x86_64"
    elif ctx.os.name.startswith("windows"):
        clang_directory = "toolchains/llvm/prebuilt/windows-x86_64"
        is_windows = True
        executable_extension = ".exe"
    else:
        fail("Unsupported operating system: " + ctx.os.name)

    sysroot_directory = "%s/sysroot" % clang_directory

    # TODO(#32): Remove this hack
    ctx.symlink("sources", "ndk/sources")

    api_level = ctx.attr.api_level or 31

    result = ctx.execute([clang_directory + "/bin/clang", "--print-resource-dir"])
    if result.return_code != 0:
        fail("Failed to execute clang: %s" % result.stderr)
    stdout = result.stdout.strip()
    if is_windows:
        stdout = stdout.replace("\\", "/")
    clang_resource_directory = stdout.split(clang_directory)[1].strip("/")

    # Use a label relative to the workspace from which this repository rule came
    # to get the workspace name.
    repository_name = ctx.attr._build.workspace_name

    ctx.template(
        "BUILD.bazel",
        ctx.attr._template_ndk_root,
        {
            "{clang_directory}": clang_directory,
        },
        executable = False,
    )

    ctx.template(
        "target_systems.bzl",
        ctx.attr._template_target_systems,
        {
        },
        executable = False,
    )

    ctx.template(
        "%s/BUILD.bazel" % clang_directory,
        ctx.attr._template_ndk_clang,
        {
            "{repository_name}": repository_name,
            "{api_level}": str(api_level),
            "{clang_resource_directory}": clang_resource_directory,
            "{sysroot_directory}": sysroot_directory,
            "{executable_extension}": executable_extension,
        },
        executable = False,
    )

    ctx.template(
        "%s/BUILD.bazel" % sysroot_directory,
        ctx.attr._template_ndk_sysroot,
        {
            "{api_level}": str(api_level),
        },
        executable = False,
    )

android_ndk_repository = repository_rule(
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "The version of the Android NDK to download. Defaults to 'latest'.",
            values = ["latest"] + NDK_VERSIONS.keys(),
        ),
        "api_level": attr.int(),
        "_build": attr.label(default = ":BUILD", allow_single_file = True),
        "_template_ndk_root": attr.label(default = ":BUILD.ndk_root.tpl", allow_single_file = True),
        "_template_target_systems": attr.label(default = ":target_systems.bzl.tpl", allow_single_file = True),
        "_template_ndk_clang": attr.label(default = ":BUILD.ndk_clang.tpl", allow_single_file = True),
        "_template_ndk_sysroot": attr.label(default = ":BUILD.ndk_sysroot.tpl", allow_single_file = True),
    },
    local = False,
    implementation = _android_ndk_repository_impl,
)
