# Recovering a lost MATCH_PASSWORD

If you lost the plaintext of your `MATCH_PASSWORD` but the secret still exists in a
repository, you can recover it without exfiltrating it in plaintext. The
`Recover MATCH_PASSWORD` workflow (`.github/workflows/recover_match_password.yml`)
encrypts the secret to a public key you control and prints only the ciphertext, so
it is safe even in a public Actions log.

## One time: create an age key

```sh
brew install age
age-keygen -o recovery_key.txt     # prints "Public key: age1..." — that's your recipient
```

Keep `recovery_key.txt` (the private key) local — never commit it.

## Recover

1. In the repository that holds the `MATCH_PASSWORD` secret, add a secret
   `RECOVERY_AGE_RECIPIENT` = the `age1...` public key printed above.
1. Put `recover_match_password.yml` on a branch of that repository.
1. Actions → **Recover MATCH_PASSWORD** → **Run workflow** (pick that branch).
1. Open the run log and copy the block between
   `----- BEGIN ENCRYPTED MATCH_PASSWORD -----` and `----- END ... -----`
   (including the `-----BEGIN AGE ENCRYPTED FILE-----` lines) into a file `secret.age`.
1. Decrypt locally with your private key:

   ```sh
   age --decrypt -i recovery_key.txt secret.age
   ```

   This prints your `MATCH_PASSWORD` exactly, byte for byte (including a trailing
   newline if the secret was stored with one — match needs it to match).

## Clean up

Delete the branch, delete the workflow run, and delete the `RECOVERY_AGE_RECIPIENT`
secret. You do **not** need to rotate `MATCH_PASSWORD`: only your public key and the
ciphertext were ever exposed, and neither reveals the password.

## Notes

- The recipient is a **secret, not a workflow input**, so whoever triggers the run
  cannot redirect the ciphertext to their own key.
- A missing `RECOVERY_AGE_RECIPIENT` fails the run with a clear error. A malformed
  (non-empty) key fails at the `age` step. Either way nothing usable is printed.
- The job uses `permissions: {}` and never checks out the repo — it only reads the
  two secrets.
