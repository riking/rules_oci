def _resolve_transitive_closure(rctx, name):
    iteration_max = 9999999
    stack=[name]
    closure={}
    for i in range(0, iteration_max + 1):
        if not len(stack):
            break
        if i == iteration_max:
            fail("_resolve_transitive_closure exhausted the iteration")

        name = stack.pop()

        if name in closure:
            continue
        
        rctx.download(
            url = ["https://formulae.brew.sh/api/formula/{}.json".format(name)],
            output = "formula.json"
        )
        
        formula = json.decode(rctx.read("formula.json"))

        stack.extend(formula["dependencies"])

        closure[name] = formula

    return closure

def _brew_bottle_impl(rctx):

    closure = _resolve_transitive_closure(rctx, rctx.attr.formula)

    print(closure)

    for (name, formula) in closure.items():
        arm64 = formula["bottle"]["stable"]["files"]["arm64_ventura"]
        rctx.download_and_extract(
            url = [arm64["url"]],
            sha256 = arm64["sha256"],
            output = "bottle/opt/{}".format(name),
            stripPrefix = "{}/{}".format(name, formula["versions"]["stable"]),
            type = "tar.gz",
            auth = {
                arm64["url"]: {
                    "type": "pattern",
                    "pattern": "Bearer <password>",
                    "password": "QQ=="
                }
            }
        )

    rctx.file("BUILD.bazel", "exports_files(['bottle'])")
    
brew_bottle = repository_rule(
    implementation = _brew_bottle_impl,
    attrs = {
        "formula": attr.string(),
    }
)
