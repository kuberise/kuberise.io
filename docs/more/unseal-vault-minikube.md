# How to unseal vault in minikube

1. get a shell of vault-0
2. `vault operator init -key-shares=1 -key-threshold=1 -format=json`
3. `vault operator unseal [unseal_keys_b64 from previous step]`

# How to generate one time password

`vault operator generate-root -init`
