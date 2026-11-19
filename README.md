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
[Other platforms](docs/maintainers.md#other-platforms).

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
DST=ssl://omero.scilifelab.se            # server you copy TO (IMPORTANT: add ssl:// prefix if you use SSO)
SRC_USER=gokhozsa                        # your username on the source server or session key if you use SSO
SRC_PASSWORD=                            # optional; if empty, omero login prompts interactively. Use session key if you use SSO.
SRC_GROUP=omero_test_20                  # group that owns the data on the source server
DST_USER=gokhozsa                        # your username on the target server or session key if you use SSO
DST_PASSWORD=                            # optional; if empty, omero login prompts interactively. Use session key if you use SSO.
DST_GROUP=omero_test_20                  # group to copy into on the target server
OBJ=Dataset:1                            # what to copy
ARCHIVE=~/omero-transfers/dataset1.zip   # where to put the archive on your computer
MERGE=false
```

Three notes on this file:

- Leave the two password lines empty. See [Passwords](docs/authentication.md#passwords) for why.
- `transfer.env` is never committed to git, so your details stay on your machine.
- If a later unpack finishes without copying any images, the target server needs `ssl://` in
front of its name. See
[Nothing was imported](docs/troubleshooting.md#nothing-was-imported).

### Step 3: Check that everything is ready

```bash
scripts/check.sh
```

This confirms your settings are filled in, that both servers answer, and that you have disk space.
It changes nothing. The last line should read:

```
==> All checks passed
```

If it does not, read the warning it printed and see [Troubleshooting](docs/troubleshooting.md).

### Step 4: Run the transfer

```bash
scripts/transfer.sh
```

Unless you filled in the password fields, you will be asked for your password twice, once per
server, and nothing is shown as you type. If a server refuses the login, you are asked again for
both the username and the password. See
[Passwords](docs/authentication.md#passwords). The script then packs the data, uploads it, and
prints a summary.

Packing downloads every original file, so a large project can take a long time. Leave the terminal
window open until it finishes.

### Step 5: Check the result, then clean up

At the end the script pauses and asks whether to delete the archive. Before answering, open the
target server in OMERO.web and confirm:

1. The project or dataset is there, with the right number of images and visible thumbnails.
2. A few images still have their tags, key-value pairs, attachments, ratings and ROIs.

Not everything comes across; see
[What is and is not copied](docs/reference.md#what-is-and-is-not-copied) for the full list.

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
setting. See [Troubleshooting](docs/troubleshooting.md).

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

## More detail

- [Passwords and single sign-on](docs/authentication.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Reference](docs/reference.md): every setting, every script, and what is copied
- [For maintainers](docs/maintainers.md)
