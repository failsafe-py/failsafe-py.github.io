# failsafe-py-docs

The documentation site for [failsafe-py](https://github.com/nicdumz/failsafe-py), a Python port
of [failsafe-go](https://github.com/failsafe-go/failsafe-go).

Ported from [failsafe-go.dev](https://failsafe-go.dev), page for page. Jekyll, served from
GitHub Pages as a project page at `/failsafe-py-docs`.

## Building

Ruby runs in a container — nothing is installed into the system or home gem paths.

```bash
bin/build.sh     # build into _site/
bin/serve.sh     # serve on http://localhost:4000/failsafe-py-docs/
```

## Project page gotcha

The site serves from a subpath, so `baseurl` is `/failsafe-py-docs` and **every** internal link
and asset must go through `relative_url`. A hard-coded `/retry` resolves locally and 404s in
production. `bin/build.sh` plus the link assertions in the commit history are the check.
