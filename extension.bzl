# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""A bzlmod extension for loading the NDK."""

load(":rules.bzl", "DEFAULT_API_LEVEL", "android_ndk_repository")
load(":ndk_versions.bzl", "NDK_VERSIONS")

def _android_ndk_repository_extension_impl(module_ctx):
    root_modules = [m for m in module_ctx.modules if m.is_root and m.tags.configure]
    if len(root_modules) > 1:
        fail("Expected at most one root module, found {}".format(", ".join([x.name for x in root_modules])))

    if root_modules:
        module = root_modules[0]
    else:
        module = module_ctx.modules[0]

    kwargs = {}
    if module.tags.configure:
        kwargs["api_level"] = module.tags.configure[0].api_level
        kwargs["version"] = module.tags.configure[0].version

    android_ndk_repository(
        name = "androidndk",
        **kwargs
    )

_CONFIGURE_TAG_CLASS = tag_class(attrs = {
    "api_level": attr.int(
        doc = "The minimum Android API level to target.",
        default = DEFAULT_API_LEVEL,
    ),
    "version": attr.string(
        mandatory = True,
        doc = "The version of the Android NDK to download.",
        values = ["latest"] + NDK_VERSIONS.keys(),
    ),
})

android_ndk_repository_extension = module_extension(
    implementation = _android_ndk_repository_extension_impl,
    tag_classes = {
        "configure": _CONFIGURE_TAG_CLASS,
    },
)
