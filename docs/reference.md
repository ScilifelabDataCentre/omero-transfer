# Reference

## Settings

| Setting | Meaning |
| --- | --- |
| `SRC` / `DST` | Server to copy from / to. May carry an `ssl://` prefix, see [Nothing was imported](troubleshooting.md#nothing-was-imported) |
| `SRC_USER` / `DST_USER` | Your username on each server |
| `SRC_PASSWORD` / `DST_PASSWORD` | Optional; if empty you are asked when needed |
| `SRC_GROUP` / `DST_GROUP` | Group on each server, by name or numeric id. Both required, and they may be named differently |
| `OBJ` | What to copy, for example `Dataset:1` |
| `ARCHIVE` | Where to write the archive; `.zip` compresses, `.tar` makes a tarball, a name with no extension writes a folder |
| `MERGE` | `true` adds to an existing project or dataset of the same name |
| `PORT` | Only if the server does not use the standard 4064. Ignored for an `ssl://` host, which carries its own port |

Settings given on the command line override the file.

## Scripts

| Script | What it does |
| --- | --- |
| `scripts/check.sh` | Checks the settings, both servers and disk space. Changes nothing |
| `scripts/pack.sh` | Downloads the data from the source into the archive |
| `scripts/unpack.sh` | Uploads the archive to the target |
| `scripts/transfer.sh` | All three in order, then offers to delete the archive |

Every script accepts `-c FILE` to use a different settings file and `-h` for help.
`unpack.sh` and `transfer.sh` also accept `--merge`.

## What is and is not copied

**Copied:** images and their original files, the project and dataset structure, tags, key-value
pairs, file attachments, ratings, comments, and ROIs.

**Not copied:** Mask ROIs, rendering settings (brightness, contrast and channel colours), and any
annotation type not listed above.

## Running the OMERO CLI by hand

The full `omero` command line is available through `uv run`:

```bash
uv run omero login -u gokhozsa -s omero-staging.c3se.chalmers.se -g omero_test_20
uv run omero transfer pack Dataset:1 ~/omero-transfers/dataset1.zip
uv run omero logout
```
