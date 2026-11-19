# omero-transfer

Copy an image, dataset or project from one OMERO server to another.

The copy happens in two stages. First the data is **packed**: everything is downloaded from the
first server into a single file on your computer, called the **archive**. Then it is **unpacked**:
the archive is uploaded to the second server, which rebuilds the same structure there.

```
source server  ->  archive on your computer  ->  target server
```

The scripts in this repo do both stages for you, using
[omero-cli-transfer](https://github.com/ome/omero-cli-transfer). You fill in one small settings
file and run one command.

## Before you start

Check all of these before your first transfer.

- **uv is installed.** This is the tool that installs everything else. Run `uv --version` to check.
  If it is missing, install it with:

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

- **You have an account on both servers.** The usernames can be different on each side.
- **The group already exists on the target server,** and you are a member of it. A group is the
  OMERO workspace that owns the data. The transfer will not create one for you.
- **You have enough free disk space** for the archive, roughly the same size as the data you are
  copying.
- **You know what you want to copy.** You need its type (Image, Dataset or Project) and its ID
  number. In OMERO.web, click the item and the ID is shown in the right-hand panel, for example
  `Dataset:1`.

This works on macOS and on Linux x86_64. For anything else, see
[Other platforms](#other-platforms).

## Step by step

### Step 1: Install (first time only)

From the repo folder, run:

```bash
uv sync
```

This downloads Python and the OMERO tools into a `.venv` folder inside the repo. It takes a minute
or two the first time and is instant afterwards. You never need to "activate" anything; the
scripts handle that themselves.

### Step 2: Write your settings file

Make your own copy of the template:

```bash
cp transfer.env.example transfer.env
```

Open `transfer.env` in a text editor and replace every value written inside angle brackets. A
finished file looks like this:

```bash
SRC=omero-staging.c3se.chalmers.se       # server you copy FROM
DST=omero.scilifelab.se                  # server you copy TO
SRC_USER=gokhozsa                        # your username on the source server
SRC_PASSWORD=                            # optional; if empty, omero login prompts interactively
DST_USER=gokhozsa                        # your username on the target server
DST_PASSWORD=                            # optional; if empty, omero login prompts interactively
GROUP=omero_test_20                      # group that owns the data
OBJ=Dataset:1                            # what to copy
ARCHIVE=~/omero-transfers/dataset1.zip   # where to put the archive on your computer
MERGE=false
```

Two notes on this file:

- Leave the two password lines empty. See [Passwords](#passwords) for why.
- `transfer.env` is never committed to git, so your details stay on your machine.

### Step 3: Check that everything is ready

```bash
scripts/check.sh
```

This confirms your settings are filled in, that both servers answer, and that you have disk space.
It changes nothing. The last line should read:

```
==> All checks passed
```

If it does not, read the warning it printed and see [Troubleshooting](#troubleshooting).

### Step 4: Run the transfer

```bash
scripts/transfer.sh
```

Unless you filled in the password fields, you will be asked for your password twice, once per
server, and nothing is shown as you type. See [Passwords](#passwords). The script then packs the
data, uploads it, and prints a summary.

Packing downloads every original file, so a large project can take a long time. Leave the terminal
window open until it finishes.

### Step 5: Check the result, then clean up

At the end the script pauses and asks whether to delete the archive. Before answering, open the
target server in OMERO.web and confirm:

1. The project or dataset is there, with the right number of images and visible thumbnails.
2. A few images still have their tags, key-value pairs, attachments, ratings and ROIs.

Once you are satisfied, answer `y` to delete the archive from your computer. If anything looks
wrong, answer `n`: the archive is kept so you can unpack it again without repeating the download.

## Choosing what to transfer

The `OBJ` setting says what gets copied. Everything inside it comes along.

```bash
OBJ=Image:19          # one image
OBJ=Dataset:1         # a dataset, with all its images
OBJ=Project:1         # a project, with all its datasets
OBJ=Image:19-25       # images 19 to 25
OBJ=Dataset:1,4,7     # datasets 1, 4 and 7
```

`Plate` and `Screen` also work, but most servers block them until an administrator changes a
setting. See [Troubleshooting](#troubleshooting).

## Passwords

`SRC_PASSWORD` and `DST_PASSWORD` are optional. If empty, the scripts will then ask you for each password
when they need it, which is the safest option. If you put passwords in the settings file, be aware of what that
means: the file stores them as ordinary readable text, and while the transfer runs, anyone else
with an account on the same machine can see them in the list of running processes.

## Single sign-on

If you sign in to OMERO.web through your institution (single sign-on), you probably have no
password that works outside the browser. Instead, OMERO.web can give you a **session token**: a
code that stands in for your login. After signing in, follow the "obtain a session token here"
link.

![Obtaining a session token in OMERO.web](assets/ss-SSO-token.png)

Paste the token into your settings file in place of the username and password for that server:

```bash
SRC_SESSION_KEY=4d8e1f2a-...
DST_SESSION_KEY=9b3c7e05-...
```

The two servers are independent, so you can use a token on one side and an ordinary username and
password on the other.

A few things worth knowing:

- **Your group still applies.** OMERO ignores the group when a token is used, so the scripts
  switch the token's session to your `GROUP` before transferring. Leave `GROUP` empty to keep
  whichever group the token already has.
- **This also changes the group in your browser.** The switch happens on the server, on the same
  session your browser is using, so OMERO.web may follow along.
- **Tokens expire.** A stale one fails with `Bad session key`; get a fresh one from the same link.
- **The scripts do not log out in this mode,** so your browser session stays alive.

## Common tasks

**Add to a dataset that already exists on the target.** By default a second dataset with the same
name is created. To put the images into the existing one instead:

```bash
scripts/transfer.sh --merge
```

**Keep settings for several different transfers.** Put each one in the `configs/` folder and
choose it with `-c`:

```bash
cp configs/staging-to-prod.env.example configs/staging-to-prod.env
scripts/transfer.sh -c configs/staging-to-prod.env
```

**Change one setting for a single run,** without editing the file:

```bash
OBJ=Dataset:4 scripts/transfer.sh
```

**Pack and unpack on different computers.** Useful when no single machine can reach both servers.
Run the first half where the source is reachable, copy the archive across, then run the second
half:

```bash
scripts/pack.sh        # on the machine that can reach the source
scripts/unpack.sh      # on the machine that can reach the target
```

## What is and is not copied

**Copied:** images and their original files, the project and dataset structure, tags, key-value
pairs, file attachments, ratings, comments, and ROIs.

**Not copied:** Mask ROIs, rendering settings (brightness, contrast and channel colours), and any
annotation type not listed above.

## Troubleshooting

**The check or a login fails with a connection error.** The server name may be wrong, or the
server may not be reachable from your network. Run `scripts/check.sh` to see which of the two
servers is unreachable.

**You see `SecurityViolation`, or an error about the group, when unpacking.** You are not a member
of that group on the target server, or the group has a different name there. If the names differ,
add `SRC_GROUP` and `DST_GROUP` to your settings file instead of `GROUP`.

**You see `Bad session key`.** The session token has expired or was copied incompletely. Get a
fresh one from OMERO.web, as described in [Single sign-on](#single-sign-on).

**You see `'transfer' is not a recognized command`.** The tools are not installed. Run `uv sync`
in the repo folder, and start the scripts from there.

**`uv sync` starts compiling `zeroc-ice` and fails.** There is no prepared package for your
computer. See [Other platforms](#other-platforms).

**Packing a Plate or Screen fails to download.** OMERO blocks these downloads by default. A server
administrator has to relax the `omero.policy.binary_access` setting before this can work.

**A second attempt at unpacking creates duplicates, or fails with a `clientPath` error.** A
previous failed attempt left images behind on the target. Delete those partial imports in
OMERO.web first, then unpack again.

## Reference

### Settings

| Setting | Meaning |
| --- | --- |
| `SRC` / `DST` | Server to copy from / to |
| `SRC_USER` / `DST_USER` | Your username on each server |
| `SRC_PASSWORD` / `DST_PASSWORD` | Optional; if empty you are asked when needed |
| `SRC_SESSION_KEY` / `DST_SESSION_KEY` | Optional; an OMERO.web session token, used instead of the username and password. See [Single sign-on](#single-sign-on) |
| `GROUP` | Group that owns the data, on both servers |
| `SRC_GROUP` / `DST_GROUP` | Only if the group name differs between servers |
| `OBJ` | What to copy, for example `Dataset:1` |
| `ARCHIVE` | Where to write the archive; `.zip` compresses, `.tar` makes a tarball, a name with no extension writes a folder |
| `MERGE` | `true` adds to an existing project or dataset of the same name |
| `PORT` | Only if the server does not use the standard 4064 |

Settings given on the command line override the file.

### Scripts

| Script | What it does |
| --- | --- |
| `scripts/check.sh` | Checks the settings, both servers and disk space. Changes nothing |
| `scripts/pack.sh` | Downloads the data from the source into the archive |
| `scripts/unpack.sh` | Uploads the archive to the target |
| `scripts/transfer.sh` | All three in order, then offers to delete the archive |

Every script accepts `-c FILE` to use a different settings file and `-h` for help.
`unpack.sh` and `transfer.sh` also accept `--merge`.

### Running the OMERO CLI by hand

The full `omero` command line is available through `uv run`:

```bash
uv run omero login -u gokhozsa -s omero-staging.c3se.chalmers.se -g omero_test_20
uv run omero transfer pack Dataset:1 ~/omero-transfers/dataset1.zip
uv run omero logout
```

## For maintainers

### Other platforms

`omero-py` needs `zeroc-ice` 3.6.5, which does not build reliably from source, so
[pyproject.toml](pyproject.toml) pins prebuilt Glencoe Software wheels for Python 3.12 under
`[tool.uv.sources]`. For another platform or a newer build, add or change the URL there using the
[macOS releases](https://github.com/glencoesoftware/zeroc-ice-py-macos-universal2/releases) or
[Linux releases](https://github.com/glencoesoftware/zeroc-ice-py-linux-x86_64/releases), keeping
the `cp312` tag in line with `requires-python`, then run `uv lock`.

### Checking the scripts

```bash
uv run --group dev shellcheck scripts/*.sh
```
