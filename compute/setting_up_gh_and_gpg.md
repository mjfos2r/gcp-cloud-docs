# Let's get gh setup and auth'd and also set up GPG to use our key

So assuming this is a fresh VM. First we gotta export our gpg key that is auth'd with github as a signing key.

```bash
# export and upload instructions go here
...
# now we have to trust the key!
gpg --list-keys --keyid-format long
# using the key_id provided. Should be something like rsa4096/ABCD12345
# where algorithm/KEY_ID
# Ok anyway
gpg --edit-key MY_KEY_ID
gpg> trust
# and then set the level of trust. For this I'm going to use 5 since it's my personal key.
gpg> 5
gpg> quit
```


we also have to make sure that the pinentry is set to pinentry-curses or pinentry-tty.

that's done via:

```bash
sudo update-alternatives --config pinentry
```

and then selecting the correct input method.

We are on a terminal so can't use the popup window!
That didn't immediately work. What did work was what was instructed in the documentation:

```bash
export GPG_TTY=$(tty)
unset DISPLAY
```

which I appended to the end of my `~/.bashrc`

Now testing that GPG is setup and our pinentry is correctly configured, test it with the following:

```bash
echo "Boy Howdy, I am encrypted." | gpg --clearsign >test.asc
```

which should return something like:

```bash
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA512

Boy Howdy, I am encrypted.
-----BEGIN PGP SIGNATURE-----

iQIzBAEBCgAdFiEECVixy9pNWAx3el4TrIbWvsgdaEQFAme3cbsACgkQrIbWvsgd
aES9YRAAkX/BtJPvRNXy0dGU7tBfMqFwesmA2gEDc0uusj157IUIn80Ijq6gXBRJ
bVKlqcURLx5HPDBxJfR0Ga98CORe96JHx5iIY8bxnKt/LNhAdSNazveSuH+601B+
ZXCLo/EYcGr0ygQGGMe+XT8EWqVKAyUkcQR62gyHdA2TOo5ehnIHDCjZYH0gMFou
n4dWUcT9ka8QybExMAMdqZrzLt5XD8pYiASi+GLEJlPpkVIqdzSCXRQJKQg6bzGx
geAEVXTJc4oswLpQ+uluZfAe9ZO0xkxA6R/vgpvr5fXB/l7sJp0O7YE6HT6vLJot
+7kAXWNFuUTAuLo773ED6n1vFHMcyQmcknK9guAZC3LUxAKfPxEvLM0UbVpPVBbs
zyl6m1ksxp5pDBzeF15DxBskSvckCbDa7mqrAluJdXKd6ECA13aJQa3kVQ9yNwQY
OxZOc4LwZU7nF8slTYmtdD//hl7f+1lnkXSzRkXW4euGQmrlvlZF6F8G+cmO1rhy
a3isZhWFOdJet4LV1q9lr0ElouR7k156fm+XQktN5NOuzg4w8B5DCIydCtG+3pTg
GKyX5ByzZb/3Zp6JSI8fk7Ci/5MPOAjw9tmB6gSvlO/tfTpNG4lwrv6vsNm/Div/
4CU4E+z8t/LWH0983zxBEd51oqloFiLdjspBix07usv5m9H91EU=
=DdI5
-----END PGP SIGNATURE-----
```

and testing the decryption via:

```bash
gpg --verify test.asc
#
# which returns:
#
gpg: Signature made Thu Feb 20 18:17:57 2025 UTC
gpg:                using RSA key <omitted_full_key>
gpg: checking the trustdb
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: depth: 0  valid:   1  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 1u
gpg: next trustdb check due at 2027-01-28
gpg: Good signature from "michael j foster (key_alias) <noreply_gh_email>" [ultimate]
gpg:                 aka "michael j foster (key_name) <my_email>" [ultimate]
#
# And decrypt to view the message:
#
gpg --decrypt test.asc
Boy Howdy, I am encrypted.
gpg: Signature made Thu Feb 20 18:17:57 2025 UTC
gpg:                using RSA key <omitted_full_key>
gpg: Good signature from "michael j foster (key_alias) <noreply_gh_email>" [ultimate]
gpg:                 aka "michael j foster (key_name) <my_email>" [ultimate]
```

Groovy now let's try again with gh.
