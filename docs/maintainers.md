# For maintainers

## Other platforms

`omero-py` needs `zeroc-ice` 3.6.5, which does not build reliably from source, so
[pyproject.toml](../pyproject.toml) pins prebuilt Glencoe Software wheels for Python 3.12 under
`[tool.uv.sources]`. For another platform or a newer build, add or change the URL there using the
[macOS releases](https://github.com/glencoesoftware/zeroc-ice-py-macos-universal2/releases) or
[Linux releases](https://github.com/glencoesoftware/zeroc-ice-py-linux-x86_64/releases), keeping
the `cp312` tag in line with `requires-python`, then run `uv lock`.

## Checking the scripts

```bash
uv run --group dev shellcheck scripts/*.sh   # static check
scripts/check.sh                             # runtime check
```

Run both. Shellcheck does not flag a call to a function that no longer exists, and an unbound
variable only surfaces when the line is reached, so `scripts/check.sh` is what catches a helper
left behind by a refactor.
