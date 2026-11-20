# Konflux

Application: `rosa-seaplane-zoa` ([Konflux UI](https://konflux-ui.apps.kflux-prd-rh02.0fk9.p1.openshiftapps.com/ns/rosa-tenant/applications/rosa-seaplane-zoa/activity))

ZOA container images build on Konflux (`rosa-tenant` / `kflux-prd-rh02`).

| Component | Containerfile | Quay image |
|-----------|---------------|------------|
| [`rosa-seaplane-zoa-lambda`](https://konflux-ui.apps.kflux-prd-rh02.0fk9.p1.openshiftapps.com/ns/rosa-tenant/applications/rosa-seaplane-zoa/components/rosa-seaplane-zoa-lambda) | `Containerfile` | [`quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-zoa-lambda`](https://quay.io/repository/redhat-user-workloads/rosa-tenant/rosa-seaplane-zoa-lambda) |
| [`rosa-seaplane-zoa-runner`](https://konflux-ui.apps.kflux-prd-rh02.0fk9.p1.openshiftapps.com/ns/rosa-tenant/applications/rosa-seaplane-zoa/components/rosa-seaplane-zoa-runner) | `Containerfile.runner` | [`quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-zoa-runner`](https://quay.io/repository/redhat-user-workloads/rosa-tenant/rosa-seaplane-zoa-runner) |
| [`rosa-seaplane-zoa-boundary`](https://konflux-ui.apps.kflux-prd-rh02.0fk9.p1.openshiftapps.com/ns/rosa-tenant/applications/rosa-seaplane-zoa/components/rosa-seaplane-zoa-boundary) | `Containerfile.boundary` | [`quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-zoa-boundary`](https://quay.io/repository/redhat-user-workloads/rosa-tenant/rosa-seaplane-zoa-boundary) |

For local builds before Konflux merges: `make images-push` publishes all three images to `quay.io/rrp-dev-ci/zoa-{lambda,runner,boundary}` (`:latest` and short commit). See [development.md](development.md) for per-image targets and repo overrides; [e2e-testing.md](e2e-testing.md) for ephemeral CI image tags.

The `zoa` CLI is built into the `zoa-runner` image and released via `.github/workflows/release-cli.yml` — no separate Konflux component.

Components `rosa-seaplane-zoa-lambda`, `rosa-seaplane-zoa-runner`, and `rosa-seaplane-zoa-boundary` share the Konflux application above, Enterprise Contract policy (`app-interface-standard`), and the same ROSA release admission. All three images use UBI9 bases and build for `linux/x86_64` and `linux/arm64`. Boundary uses versioned multi-architecture UBI tags rather than architecture-specific manifest digests. Boundary is not a hermetic build: the image downloads kubectl, the AWS CLI, and Claude Code at build time.

## Pipelines

| PipelineRun | Component | Trigger |
|-------------|-----------|---------|
| `zoa-lambda-on-pull-request` / `zoa-lambda-on-push` | `rosa-seaplane-zoa-lambda` | `Containerfile`, `cmd/zoa-lambda/**`, shared Go paths |
| `zoa-runner-on-pull-request` / `zoa-runner-on-push` | `rosa-seaplane-zoa-runner` | `Containerfile.runner`, `cmd/zoa-runner/**`, `cmd/zoa/**`, shared Go paths |
| `zoa-boundary-on-pull-request` / `zoa-boundary-on-push` | `rosa-seaplane-zoa-boundary` | `Containerfile.boundary`, `boundary/**`, `cmd/zoa/**`, shared Go paths, `Makefile` |

## Dependency updates (Mintmaker / Renovate)

Konflux **Mintmaker** reads [`renovate.json`](../renovate.json) on a schedule and opens PRs (many **automerge** after Prow + Konflux pass).

| What                              | How it is updated                                                                                                |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| UBI / go-toolset **base image tags** | `dockerfile` manager on `Containerfile*` (`ARG BASE_IMAGE`, `BUILDER_IMAGE`, `FROM …`)                        |
| **Go modules**                    | `gomod` manager                                                                                                  |
| **Tekton** refs                   | `tekton` manager on `.tekton/`                                                                                   |
| **kubectl** in boundary           | `custom.regex` on `Containerfile.boundary` (`KUBECTL_VERSION`)                                                   |
| **Claude Code** in boundary       | `custom.regex` on `Containerfile.boundary` (`CLAUDE_CODE_VERSION`, release tags without `v` prefix)              |
| **AWS CLI v2**                    | `custom.regex` on `Containerfile.boundary` (`AWS_CLI_VERSION`). `aws/aws-cli` stable versions are git tags, so the datasource is `github-tags` (not GitHub Releases), and only `x.y.z` tags are accepted |
| **jq / vim / …** RPMs             | Ride along when **ubi-minimal** digest updates                                                                   |

Patch, minor, and digest bumps of those boundary pins are grouped with other Containerfile updates and automerge when Prow and Konflux pass. Major bumps stay for manual review. `jq` and the other UBI packages have no separate pin.