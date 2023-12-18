# Images containing Go applications

Typical users will migrate from
[`go_image`](https://github.com/bazelbuild/rules_docker#go_image) in rules_docker.

## Base image

First, you'll need a base image.

It's wise to minimize changes by using the same one your current `go_image` uses.
The logic for choosing the default base in rules_docker is in
[go_image.bzl](https://github.com/bazelbuild/rules_docker/blob/fc729d85f284225cfc0b8c6d1d838f4b3e037749/go/image.bzl#L114)

Or, you can just use bazel query to find out:

```
$ bazel query --output=build hello_world:hello_world_go_image
Starting local Bazel server and connecting to it...
# /home/alexeagle/Projects/hello_world/BUILD.bazel:22:9
_app_layer(
  name = "hello_world_go_image",
  base = select({"@io_bazel_rules_docker//:debug": "@go_debug_image_base//image:image", "@io_bazel_rules_docker//:fastbuild": "@go_image_base//image:image", "@io_bazel_rules_docker//:optimized": "@go_image_base//image:image", "//conditions:default": "@go_image_base//image:image"}),
...
)
```

Since we don't use the "debug" config, this tells us that we use `@go_base_image`, we need one more lookup to see what that uses:

```
$ bazel query --output=build @go_image_base//image:image
# /shared/cache/bazel/user_base/bf7b6accf6f1187bd5511f3fbf7b21b9/external/go_image_base/image/BUILD:4:17
container_import(
  name = "image",
  base_image_registry = "gcr.io",
  base_image_repository = "distroless/base",
...
)
```

Now that we know it's `gcr.io/distroless/base` we can pull the same base image by adding to WORKSPACE:

```
# WORKSPACE
load("@rules_oci//oci:pull.bzl", "oci_pull")

oci_pull(
    name = "distroless_base",
    # digest version 2023-12-16
    # TODO(2024-06-10): Update the digest hash and change this TODO to 6 months away.
    digest = "sha256:6c1e34e2f084fe6df17b8bceb1416f1e11af0fcdb1cef11ee4ac8ae127cb507c",
    image = "gcr.io/distroless/base",
    platforms = ["linux/amd64","linux/arm64"],
)

# MODULE.bazel
oci = use_extension("@rules_oci//oci:extensions.bzl", "oci")
oci.pull(
    name = "distroless_base",
    image = "gcr.io/distroless/base",
    platforms = ["linux/amd64","linux/arm64"],
    # digest version 2023-12-16
    # TODO(2024-06-10): Update the digest hash and change this TODO to 6 months away.
    digest = "sha256:6c1e34e2f084fe6df17b8bceb1416f1e11af0fcdb1cef11ee4ac8ae127cb507c",
)
use_repo(oci, "distroless_base")
```

See more details in the [oci_pull docs](/docs/pull.md)

## The go_image

rules_docker makes you repeat the attributes of `go_binary` into `go_layer`.
This is a "layering violation" (get it?).

In rules_oci, you just start from a normal `go_binary` (typically by having Gazelle write it).
For this example let's say it's `go_binary(name = "app", ...)`.

Next, put that file into a layer, which is just a `.tar` file:

```
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

pkg_tar(
    name = "tar",
    srcs = [":app"],
)
```

Finally, add your layer to the base image:

```
load("@rules_oci//oci:defs.bzl", "oci_image")

oci_image(
    name = "image",
    base = "@distroless_base",
    tars = [":tar"],
    entrypoint = ["/app"],
)
```

## Example

A full example can be found at <https://github.com/aspect-build/bazel-examples/tree/main/oci_go_image>.
