# Damson Cloud GCP Cloud Foundations: API management

Terraform module of the Damson Cloud GCP Cloud Foundations managing the API keys of a Google Cloud organisation in its API Management Hub project:

* the KMS key encrypting the values of the API keys' secrets, used by the common environment's SREs and decrypted by `tf-bootstrap` and `tf-plan`,
* the API keys manager service account, reading the development environment's secrets only, impersonated by the API keys' accessors group,
* a service account per environment, tagged with it, to which the environment's Gemini API keys are bound,
* the Gemini API keys, restricted to the Gemini API, with their key strings in regional secrets tagged with the keys' environments and readable by the declared service accounts,
* the secrets of the other API keys, with values encrypted with the KMS key in the configuration, decrypted by `tf-bootstrap` when writing them,
* a deny policy on the hub project, letting only `tf-bootstrap` manage the API keys and the secrets, only `tf-bootstrap` and `tf-plan` read the key strings, and only them,
  the API keys manager and the declared service accounts read the secrets,
* the secret access of `tf-plan`, which reads the key strings, the secrets and the decrypted values when planning,
* when the hub project is in a VPC Service Controls perimeter, the ingress rules letting the API keys' accessors group impersonate the API keys manager, and the API keys
  manager and the declared service accounts read the secrets from outside the perimeter.

## Usage

> [!IMPORTANT]
> The module requires the `google.api_keys` provider alias, passed in its `providers` argument together with the default `google` provider, as below. Configure the alias with
> `user_project_override = true` and the hub project as `billing_project`, otherwise creating the API keys fails with `SERVICE_DISABLED` for `apikeys.googleapis.com` in the calling
> identity's project. See [Billing the API Keys API](#billing-the-api-keys-api).

```hcl
# Bills the API Keys API to the hub project
provider "google" {
  alias                 = "api_keys"
  user_project_override = true
  billing_project       = module.organization.api_management_project_id
}

module "api_management" {
  source  = "damsoncloud/cf-api-management/google"
  version = "X.Y.Z"

  providers = {
    google          = google
    google.api_keys = google.api_keys
  }

  domain                    = "example.com"
  folders                   = module.hierarchy.folders
  environment_tag_key       = module.hierarchy.environment_tag_key
  environment_tag_values    = module.hierarchy.environment_tag_values
  api_management_project_id = module.organization.api_management_project_id
  tf_bootstrap_email        = module.bootstrap.tf_bootstrap_email
  tf_plan_email             = module.bootstrap.tf_plan_email

  vpc_service_controls = {
    perimeter_name = module.vpc_service_controls.perimeter_name
    mode           = "enforced"
  }

  gemini_api_keys = {
    chatbot = {
      environment_name                 = "development"
      labels                           = { department = "engineering", owner = "team_at_example_com" }
      accessor_service_accounts_emails = ["chatbot@dev-chatbot-a1b2.iam.gserviceaccount.com"]
    }
  }

  api_keys_secrets = {
    maps_api = {
      environment_name              = "development"
      labels                        = { department = "engineering", owner = "team_at_example_com" }
      encrypted_secret_data         = "CiQA..." # see the api_keys_secrets input
      encrypted_secret_data_version = 1
    }
  }
}
```

Pin an exact version. New versions are published as immutable GitHub releases with `vX.Y.Z` tags, following [semantic versioning](https://semver.org/).

See [`examples/basic`](examples/basic) for a Gemini API key with the hub created by cf-hierarchy, cf-bootstrap and cf-organization, and
[`examples/complete`](examples/complete) for server-restricted keys, the other API keys' secrets, accessor service accounts and the perimeter's ingress rules.

### Billing the API Keys API

The API Keys API is billed to the calling identity's own project, e.g. the bootstrap project of `tf-bootstrap` and `tf-plan`, unless a billing project is set. The module
therefore creates the API keys, and reads their key strings, with the `google.api_keys` provider, which the caller configures to bill the hub project, where the API is enabled
and allowed by the organisation policies. The module grants `tf-bootstrap` and `tf-plan` `roles/serviceusage.serviceUsageConsumer` on the hub project, which billing it requires.
The billing project must be known when planning, e.g. read from the cf-organization state.

### Encrypting the API keys' values

The values of `api_keys_secrets` are base64-encoded before they are encrypted, and the ciphertext is base64-encoded, by a member of the common environment's SREs group:

```bash
printf %s "$(printf %s "$VALUE" | base64 -w0)" |
  gcloud kms encrypt --key=<kms_crypto_key output> --plaintext-file=- --ciphertext-file=- |
  base64 -w0
```

`tf-bootstrap` decrypts the values when writing them to Secret Manager, and `tf-plan` when planning, so the base64-encoded values are stored in the Terraform state. A changed
value is written as a new secret version only when its `encrypted_secret_data_version` is incremented.

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| api\_keys\_accessors\_group\_name | Name of the group impersonating the API keys manager service account to read the development environment's secrets, without the domain. | `string` | `"gcp-api-keys-accessors"` | no |
| api\_keys\_secrets | Secrets of the API keys other than Gemini's, by purpose, each in a regional secret named `<environment short name>-<region>-<purpose>` and tagged with its environment. Each secret has:   `environment_name`, the folder name of its environment;   `labels` of the secret, as those of `gemini_api_keys`;   `encrypted_secret_data`, the base64-encoded value, encrypted with the `kms_crypto_key` and base64-encoded again, as described in the README;   `encrypted_secret_data_version`, incremented to write a changed value as a new secret version, as changes of the value alone are ignored;   `accessor_service_accounts_emails`, the service accounts reading the secret. tf-bootstrap decrypts the values when writing them, and tf-plan when planning, so the base64-encoded values are stored in the Terraform state. | ```map(object({ environment_name = string labels = map(string) encrypted_secret_data = string encrypted_secret_data_version = number accessor_service_accounts_emails = optional(set(string), []) }))``` | `{}` | no |
| api\_management\_project\_id | ID of the API Management Hub project, e.g. the `api_management_project_id` output of cf-organization. | `string` | n/a | yes |
| domain | Domain of the organisation's groups. | `string` | n/a | yes |
| environment\_tag\_key | ID of the `environment` tag key (`tagKeys/<id>`), e.g. the `environment_tag_key` output of cf-hierarchy. | `string` | n/a | yes |
| environment\_tag\_values | IDs of the `environment` tag values (`tagValues/<id>`) by folder name, e.g. the `environment_tag_values` output of cf-hierarchy. Only the secrets tagged `development` are readable by the API keys' accessors. | `map(string)` | n/a | yes |
| folders | The folders by folder name, e.g. the `folders` output of cf-hierarchy:   `id`, the resource name (`folders/<id>`);   `short_name`, the environment's short name, null for folders other than environments;   `common`, whether it is the common environment. Each environment gets a Gemini API keys service account; the common environment's short name prefixes the resources' names and names its SREs group. | ```map(object({ id = string short_name = optional(string) common = optional(bool, false) }))``` | n/a | yes |
| gemini\_api\_keys | Gemini API keys by purpose, each restricted to the Gemini API, bound to its environment's service account and stored in a regional secret tagged with its environment. The key and the secret are named `<environment short name>-<region>-geminiapi-<purpose>`. Each key has:   `environment_name`, the folder name of its environment;   `labels` of the secret, following the labelling strategy of the customer design document, with the `environment` label set to the environment's short name:   at least `department` and `owner`, e.g. a team name or an email with `_at_` and `_` in place of `@` and dots;   `display_name` of the key;   `accessor_service_accounts_emails`, the service accounts reading the secret;   `server_key_restrictions`, the IP addresses or ranges allowed to use the key. | ```map(object({ environment_name = string labels = map(string) display_name = optional(string) accessor_service_accounts_emails = optional(set(string), []) server_key_restrictions = optional(object({ allowed_ips = list(string) })) }))``` | `{}` | no |
| kms\_key\_rotation\_period | Rotation period of the KMS key, in seconds with an `s` suffix; earlier key versions keep decrypting the values encrypted with them. | `string` | `"7776000s"` | no |
| region | Region of the KMS key and the secrets, part of their names. | `string` | `"europe-west4"` | no |
| sres\_group\_suffix | Suffix of the common environment's SREs group (`gcp-<common short name>-<suffix>`), encrypting the values of the API keys' secrets. | `string` | `"sres"` | no |
| tf\_bootstrap\_email | Email of the `tf-bootstrap` service account applying the module, e.g. the `tf_bootstrap_email` output of cf-bootstrap, decrypting the KMS-encrypted values of the API keys' secrets. | `string` | n/a | yes |
| tf\_plan\_email | Email of the `tf-plan` service account planning the module, e.g. the `tf_plan_email` output of cf-bootstrap, decrypting the KMS-encrypted values and reading the API keys' key strings and secrets when planning. | `string` | n/a | yes |
| vpc\_service\_controls | The VPC Service Controls perimeter around the hub project, to which the ingress rules of the API keys' accessors from outside it are added; not added when null:   `perimeter_name`, the perimeter's resource name, e.g. the `perimeter_name` output of cf-organization's vpc-service-controls submodule;   `mode`, the submodule's mode: the rules are added to the dry-run configuration, and to the enforced one too when `enforced`. | ```object({ perimeter_name = string mode = optional(string, "dry_run") })``` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| api\_keys\_secrets | IDs of the other API keys' secrets (`projects/<project>/locations/<region>/secrets/<name>`), by purpose. |
| api\_manager\_email | Email of the API keys manager service account, impersonated by the API keys' accessors. |
| deny\_policy | ID of the deny policy protecting the API keys and secrets of the hub project. |
| gemini\_api\_keys | IDs of the Gemini API keys' secrets (`projects/<project>/locations/<region>/secrets/<name>`), by purpose. |
| gemini\_api\_service\_accounts | Emails of the service accounts the Gemini API keys are bound to, by environment folder name. |
| kms\_crypto\_key | ID of the KMS key encrypting the values of the API keys' secrets (`projects/<project>/locations/<region>/keyRings/<name>/cryptoKeys/<name>`), e.g. for `gcloud kms encrypt --key`. |
<!-- markdownlint-restore -->
<!-- END_TF_DOCS -->

## Releases

Releases are dispatched manually on `main` with the [`release.yaml`](.github/workflows/release.yaml) workflow, choosing the part of the version to increase. It calls the
[`github-release.yaml`](https://github.com/damsoncloud/dcp.sdlc#reusable-workflows) reusable workflow, which creates the GitHub release and its tag. The Terraform Registry
publishes the new version from the tag.

## Security

See [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## Development

The repository uses [devenv](https://devenv.sh) with the shared [devenvbase](https://github.com/damsoncloud/dcp.sdlc/blob/main/devenvbase/README.md), pinned to a
[dcp.sdlc](https://github.com/damsoncloud/dcp.sdlc) release in `devenv.yaml`.

* `devenv shell` starts the shell.
* `devenv test` runs the git hooks and tests.
* `terraform_docs` regenerates the inputs and outputs above, which the `terraform-docs` git hook also does on commit.

The weekly `dcp.sdlc check` workflow opens an issue when a newer dcp.sdlc release is available. Upgrade with `devenv shell -- dcp_sdlc_upgrade_pr`, which also updates
the devenv inputs, runs the tests and opens a pull request.

## Licence

[Apache License 2.0](LICENSE)
