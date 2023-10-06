def _deb_import_impl(rctx):
    rctx.download_and_extract(
        url = ctx.attr.urls,
        type = "deb",
        sha256 = ctx.attr.sha256,
    )
    rctx.extract("data.tar.xz")

deb_import = repository_rule(
    implementation = _deb_import_impl,
    attrs = {
        "urls": attr.label_list(),
        "sha256": attr.string()
    }
)
