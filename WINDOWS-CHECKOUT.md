# Checking this repository out on Windows

Upstream ships `custom_components/fluidra_pool/select/aux.py`. `AUX` is a reserved DOS device
name, alongside `CON`, `PRN`, `NUL`, `COM1`–`COM9` and `LPT1`–`LPT9`. The Win32 layer refuses to
create a file with that stem regardless of extension, so a plain `git checkout`, `git pull` or
`git merge` that touches it fails:

```
error: invalid path 'custom_components/fluidra_pool/select/aux.py'
```

Forcing the write is not enough on its own — Git creates the entry and then cannot stat it back:

```
error: unable to stat just-written file custom_components/fluidra_pool/select/aux.py:
No such file or directory
```

Linux and macOS are unaffected. This is a Windows-only limitation.

## Working configuration

Two settings are needed together. `core.longpaths` makes Git address files through the `\\?\`
extended-length prefix, which bypasses the reserved-name check; sparse-checkout keeps the file
out of the working tree so nothing tries to materialise it later.

```bash
git config core.longpaths true
git config core.protectNTFS false

git sparse-checkout init --no-cone
printf '/*\n!/custom_components/fluidra_pool/select/aux.py\n' > .git/info/sparse-checkout
git sparse-checkout reapply
```

Apply this after cloning and before the first `pull` or `merge` from upstream. `.git/info/` is not
versioned, so a fresh clone needs it again.

## What this does and does not affect

The blob stays in the index and in history, so the repository remains complete, diffable and
pushable. Only the working tree lacks that one file.

Verify with:

```bash
git ls-files --stage custom_components/fluidra_pool/select/aux.py
git status --short          # must not report a deletion
```

`git status` reporting the file as deleted means sparse-checkout is not active; re-apply the
configuration above rather than committing the deletion.

Read `select/aux.py` through `git show HEAD:custom_components/fluidra_pool/select/aux.py` when its
contents are needed. Editing it requires a filesystem without the restriction — WSL, a container,
or a Linux/macOS host.

## Security note

`core.protectNTFS` guards against NTFS path tricks such as 8.3 short names and trailing dots or
spaces. Disabling it is scoped to this repository by `git config` (not `--global`), and is only
justified here because the offending path comes from a known upstream. Do not carry the setting
over to repositories whose contents are not trusted.
