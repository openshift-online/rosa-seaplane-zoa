# Konflux

ZOA container images build on Konflux (`rosa-tenant` / `kflux-prd-rh02`).

| Component | Containerfile | Quay image |
|-----------|---------------|------------|
| `rosa-seaplane-zoa-lambda` | `Containerfile` | `quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-zoa-lambda` |
| `rosa-seaplane-zoa-runner` | `Containerfile.runner` | `quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-zoa-runner` |
| `rosa-seaplane-zoa-boundary` | `Containerfile.boundary` | `quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-zoa-boundary` |

Local dev builds (before Konflux or for ephemeral): `make image-boundary`, `make image-push-boundary`, or `make images-push` (pushes to `quay.io/rrp-dev-ci/zoa-boundary` by default).

Application: `rosa-seaplane-zoa` ([Konflux UI](https://konflux-ui.apps.kflux-prd-rh02.0fk9.p1.openshiftapps.com/ns/rosa-tenant/applications/rosa-seaplane-zoa/activity))

The `zoa` CLI is built into the `zoa-runner` image and released via `.github/workflows/release-cli.yml` — no separate Konflux component.

Lambda and runner were registered in [konflux-release-data MR !21738](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/merge_requests/21738) and renamed to `rosa-seaplane-zoa-lambda` / `rosa-seaplane-zoa-runner` under application `rosa-seaplane-zoa`. `rosa-seaplane-zoa-boundary` uses the same application, Enterprise Contract policy (`app-interface-standard`), and release admission. All three images build for `linux/x86_64` and `linux/arm64`. Every Go build stage uses the hardened (Project Hummingbird) FIPS Go builder `registry.access.redhat.com/hi/go:latest-fips-builder`, digest-pinned to a multi-architecture image index, as in `rosa-seaplane-kube-applier` and `rosa-seaplane-ecr-creds-sync`; `zoa-lambda` and `zoa-runner` run on the matching hardened FIPS runtime `hi/go:latest-fips` (`GODEBUG=fips140=on`). `zoa-boundary` keeps a UBI9 `ubi-minimal` base for its final image because the operator shell installs RPMs, creates the `sre` user, and needs an interactive shell for ECS Exec; it uses versioned multi-architecture UBI tags rather than architecture-specific manifest digests. Boundary is not a hermetic build: the image downloads kubectl, the AWS CLI, and Claude Code at build time.

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
| Hardened FIPS Go / UBI **base image pins** | `dockerfile` manager on `Containerfile*` and `ci/Containerfile` (`ARG BASE_IMAGE`, `BUILDER_IMAGE`, `FROM …`); `hi/go` references are digest pins refreshed by the digest rules |
| **Go modules**                    | `gomod` manager                                                                                                  |
| **Tekton** refs                   | `tekton` manager on `.tekton/`                                                                                   |
| **kubectl** in boundary           | `custom.regex` on `Containerfile.boundary` (`KUBECTL_VERSION`)                                                   |
| **Claude Code** in boundary       | `custom.regex` on `Containerfile.boundary` (`CLAUDE_CODE_VERSION`, release tags without `v` prefix)              |
| **AWS CLI v2**                    | `custom.regex` on `Containerfile.boundary` (`AWS_CLI_VERSION`). `aws/aws-cli` stable versions are git tags, so the datasource is `github-tags` (not GitHub Releases), and only `x.y.z` tags are accepted |
| **jq / vim / …** RPMs             | Ride along when **ubi-minimal** digest updates                                                                   |

Patch, minor, and digest bumps of those boundary pins are grouped with other Containerfile updates and automerge when Prow and Konflux pass. Major bumps stay for manual review. `jq` and the other UBI packages have no separate pin.

Local image builds remain `make image-boundary` / `make image-push-boundary` (default registry `quay.io/rrp-dev-ci/zoa-boundary`). Ephemeral Prow keeps using that CI image; it is separate from the Konflux production repository.

## Merge order

Onboard boundary in this order so the build service account and Quay repository exist before pipelines run:

1. `konflux-release-data` — component `rosa-seaplane-zoa-boundary`, ImageRepository, Enterprise Contract scenario, and the rosa release-admission mapping
2. This repo — `.tekton/zoa-boundary-pull-request.yaml` and `.tekton/zoa-boundary-push.yaml`
3. `openshift/release` — required-if-present context `Konflux kflux-prd-rh02 / zoa-boundary-on-pull-request`
