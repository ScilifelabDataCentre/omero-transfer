# omero-transfer

Scripts and instructions to transfer data between two OMERO instances with
[omero-cli-transfer](https://github.com/ome/omero-cli-transfer).

`omero transfer` copies an Image, Dataset, Project, Plate or Screen from one OMERO server to
another. Packing writes the original files plus a `transfer.xml` describing links, annotations and
ROIs into a single archive; unpacking imports those files on the target server and re-creates the
structure around them. The scripts in this repo wrap those two steps around a small config file.

## Prerequisites

- [uv](https://docs.astral.sh/uv/getting-started/installation/). It installs Python 3.12 itself
  if needed.
- macOS (Intel or Apple Silicon) or Linux x86_64. See [Other platforms](#other-platforms) otherwise.
- Access to port 4064 on both servers. Some instances are only reachable over a VPN.
- An account on both servers, and membership in the group you transfer into. The group must
  already exist on the target; `unpack` does not create it.
- Free disk space roughly equal to the size of the raw data, since the archive is written locally.

## Quick start

```bash
uv sync                               # creates .venv with omero-py, omero-cli-transfer, zeroc-ice
cp transfer.env.example transfer.env  # then edit transfer.env
scripts/transfer.sh
```

`transfer.sh` runs the preflight checks, packs on the source, unpacks on the target, prints a
verification checklist and asks before deleting the local archive. Each login prompts for the
password.

## Configuration

`transfer.env` holds the only values that change between transfers:

| Variable | Meaning |
| --- | --- |
| `SRC` / `DST` | Hostnames to pack from and unpack into |
| `SRC_USER` / `DST_USER` | OMERO login on the source / target server |
| `SRC_PASSWORD` / `DST_PASSWORD` | Optional; if empty, `omero login` prompts interactively |
| `GROUP` | Group that owns the data, must exist on both servers |
| `SRC_GROUP` / `DST_GROUP` | Optional, when the group name differs between servers |
| `OBJ` | Object to transfer, see [Examples](#examples) |
| `ARCHIVE` | Local archive path; `.zip` compresses, `.tar` makes a tarball, no extension writes a directory |
| `MERGE` | `true` adds into an existing Project/Dataset with the same name on the target |
| `PORT` | Optional, defaults to 4064 |

Keep several transfers side by side in `configs/` and pick one with `-c`:

```bash
cp configs/staging-to-prod.env.example configs/staging-to-prod.env
scripts/transfer.sh -c configs/staging-to-prod.env
```

Variables set on the command line override the file, which is handy for one-off changes:

```bash
OBJ=Dataset:4 ARCHIVE=~/omero-transfers/dataset4.zip scripts/transfer.sh
```

`transfer.env` and `configs/*.env` are gitignored; only the `.example` templates are tracked.

## Scripts

| Script | What it does |
| --- | --- |
| `scripts/check.sh` | Checks uv and `omero transfer`, the config, port reachability on both servers and disk space |
| `scripts/pack.sh` | Logs in to `SRC`, runs `omero transfer pack "$OBJ" "$ARCHIVE"`, logs out |
| `scripts/unpack.sh` | Logs in to `DST`, runs `omero transfer unpack [--merge] "$ARCHIVE"`, logs out |
| `scripts/transfer.sh` | All of the above in sequence, then offers to delete the archive |

All scripts accept `-c CONFIG` and `-h`; `unpack.sh` and `transfer.sh` also accept `--merge`.
Running pack and unpack separately is useful when the two servers are reachable from different
networks: pack on one machine, copy the archive, unpack on another.

To run the CLI by hand, prefix commands with `uv run`:

```bash
uv run omero login -u "$SRC_USER" -s "$SRC" -g "$GROUP"
uv run omero transfer pack Dataset:1 ~/omero-transfers/dataset1.zip
uv run omero logout
```

## Examples

```bash
OBJ=Image:19          # single image
OBJ=Dataset:1         # dataset with its images, annotations and ROIs
OBJ=Project:1         # project with all its datasets
OBJ=Image:19-25       # range
OBJ=Dataset:1,4,7     # list
```

The worked example in `configs/staging-to-prod.env.example` moves `Dataset:1` from
`omero-staging.c3se.chalmers.se` to `omero.scilifelab.se` in group `omero_test_20`. Connect to the
Chalmers VPN first. The dataset arrives on production as a new orphaned Dataset with the same
name, images, annotations and ROIs; use `--merge` if a Dataset with that name already exists there.

## Verify and clean up

1. Open the target in OMERO.web and confirm the Project/Dataset tree, image count and thumbnails.
2. Spot-check tags, key-value pairs, file attachments, ratings and ROIs on a few images.
3. Delete the local archive once the data is confirmed.

Only MapAnnotations, Tags, FileAnnotations, ratings and CommentAnnotations are transferred. All ROI
types except Masks are supported. Rendering settings are not included.

## Other platforms

`omero-py` needs `zeroc-ice` 3.6.5, which does not build reliably from source, so
`pyproject.toml` pins prebuilt Glencoe Software wheels for Python 3.12 under `[tool.uv.sources]`.
For another platform or a newer build, add or change the URL there from the
[macOS releases](https://github.com/glencoesoftware/zeroc-ice-py-macos-universal2/releases) or
[Linux releases](https://github.com/glencoesoftware/zeroc-ice-py-linux-x86_64/releases), keeping
the `cp312` tag in line with `requires-python`, then run `uv lock`.

## Troubleshooting

- **`uv sync` tries to build `zeroc-ice` from source.** Your platform has no wheel entry in
  `pyproject.toml`; see [Other platforms](#other-platforms).
- **`'transfer' is not a recognized command`.** Run `uv sync` in this repo, and call the CLI through
  the scripts or `uv run omero`.
- **Connection refused or timeout on login.** Check the hostname, that the VPN is connected if the
  instance needs one, and that port 4064 is reachable: `scripts/check.sh`.
- **`SecurityViolation` or group errors on unpack.** The user is not a member of the group on the
  target, or the group name differs between servers (set `SRC_GROUP` / `DST_GROUP`).
- **Plate or Screen download errors.** OMERO blocks binary downloads of plates by default. The
  server needs `omero.policy.binary_access` relaxed before such a pack can succeed.
- **A retried unpack creates duplicates or fails on `clientPath`.** Images left behind by a failed
  unpack are not annotated, so the retry collides with them. Delete the partial import on the
  target first.

## Development

```bash
uv run --group dev shellcheck scripts/*.sh
```
