# failsafe-py.github.io

The documentation site for [failsafe-py](https://github.com/failsafe-py/failsafe-py).

Jekyll, served from GitHub Pages at <https://failsafe-py.github.io>.

## Building

Ruby runs in a container — nothing is installed into the system or home gem paths.

```bash
bin/build.sh     # build into _site/
bin/serve.sh     # serve on http://localhost:4000/
```

## Links

This is an **organisation site**, so it serves from the root and `baseurl` is empty.

Internal links still go through `relative_url`, via a reference in
`_includes/common-links.html`. That costs nothing today and makes a move to a custom
domain or a subpath a one-line config change rather than an edit to every page.
