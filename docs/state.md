# State

Each stack under `tofu/stacks/` keeps its state in `terraform.tfstate` next to the code, committed to the repo. OpenTofu encrypts state and plan files with a passphrase from `secrets/tofu.sops.yaml`; the `tofu` tasks pass it in through `TF_ENCRYPTION`, and without it `tofu plan` fails.

A pull request that changes a stack gets a `tofu plan` comment for it, updated on every push. After the merge, CI applies the stack and commits its state to `main`; one apply per stack runs at a time.

A stack with a `.ci-skip` file (its content says why) is left out of CI plan, apply and drift.

The daily `drift` workflow, also started by hand from the Actions tab, plans every stack and fails when the infrastructure no longer matches the code.
