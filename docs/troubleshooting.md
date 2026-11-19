# Troubleshooting

**The check or a login fails with a connection error.** The server name may be wrong, or the
server may not be reachable from your network. Run `scripts/check.sh` to see which of the two
servers is unreachable.

**You see `SecurityViolation`, or an error about the group, when unpacking.** You are not a member
of `DST_GROUP` on the target server, or the group is named differently there. The two groups are
set independently, so `SRC_GROUP` and `DST_GROUP` do not have to match.

**The data arrives in the wrong group.** OMERO falls back to your default group without
complaining when you ask for one you are not a member of. Check `DST_GROUP` against the group
list in OMERO.web on the target server.

**Your login is rejected and you use single sign-on.** The session token has expired or was
copied incompletely, and it fails the same way a wrong password would. Get a fresh one from
OMERO.web, as described in [Single sign-on](authentication.md#single-sign-on).

**You see `'transfer' is not a recognized command`.** The tools are not installed. Run `uv sync`
in the repo folder, and start the scripts from there.

**`uv sync` starts compiling `zeroc-ice` and fails.** There is no prepared package for your
computer. See [Other platforms](maintainers.md#other-platforms).

**Packing a Plate or Screen fails to download.** OMERO blocks these downloads by default. A server
administrator has to relax the `omero.policy.binary_access` setting before this can work.

<a id="nothing-was-imported"></a>
**Unpacking finishes but no images arrive.** Look in the output for `Insecure connection
requested, falling back`, then `Obtained null object proxy`, and finally `Image corresponding to
Image:1 not found. Skipping.` The image importer first connects to the server encrypted, then
tries to switch to an unencrypted connection for the upload, and that second connection is
blocked on many servers. Keep it encrypted by putting `ssl://` in front of that server name:

```bash
DST=ssl://omero.scilifelab.se
```

Then unpack again. The archive from the earlier attempt can be reused; there is no need to pack a
second time. Delete any empty projects or datasets the failed attempt left behind first.

**A second attempt at unpacking creates duplicates, or fails with a `clientPath` error.** A
previous failed attempt left images behind on the target. Delete those partial imports in
OMERO.web first, then unpack again.
