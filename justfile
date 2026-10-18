hurl := "hurl --test --jobs 1 --variables-file tests/hurl/vars.env"

# List recipes
default:
    @just --list

# Podman compose provider
compose := "podman-compose -f testenv/compose.yaml"

# Podman: start Forgejo, oauth2-proxy, nginx, runner (fresh Forgejo, bootstrapped by `setup`)
testenv-up:
    {{compose}} up -d forgejo
    {{compose}} --profile setup run --rm setup
    {{compose}} up -d oauth2-proxy nginx runner

# Podman: run the suite (or given files, relative to tests/hurl/) in the Hurl container
testenv-test *files:
    {{compose}} --profile test run --rm hurl --test --jobs 1 --variables-file /tests/hurl/vars.env /testenv/wait.hurl {{ if files == "" { "--glob '*.hurl'" } else { files } }}

# Podman: stop and remove everything, including volumes
testenv-down:
    {{compose}} --profile test --profile setup down --volumes

# Podman: up, test, down in testenv (cleans up even if tests fail)
test:
    just testenv-up
    just testenv-test || { just testenv-down; exit 1; }
    just testenv-down
