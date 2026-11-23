# Damson Cloud GCP Cloud Foundations: API management

Terraform module of the Damson Cloud GCP Cloud Foundations managing the API keys of a Google Cloud organisation in its API Management Hub project:

* the KMS key encrypting the values of the API keys' secrets, used by the common environment's SREs and decrypted by `tf-bootstrap`,
* the API keys manager service account, reading the development environment's secrets only, impersonated by the API keys' accessors group,
* a service account per environment, tagged with it, to which the environment's Gemini API keys are bound.

## Usage

```hcl
module "api_management" {
  source  = "damsoncloud/cf-api-management/google"
  version = "X.Y.Z"

  domain                    = "example.com"
  folders                   = module.hierarchy.folders
  environment_tag_key       = module.hierarchy.environment_tag_key
  environment_tag_values    = module.hierarchy.environment_tag_values
  api_management_project_id = module.organization.api_management_project_id
  tf_bootstrap_email        = module.bootstrap.tf_bootstrap_email
}
```

Pin an exact version. New versions are published as immutable GitHub releases with `vX.Y.Z` tags, following [semantic versioning](https://semver.org/).

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| api\_keys\_accessors\_group\_name | Name of the group impersonating the API keys manager service account to read the development environment's secrets, without the domain. | `string` | `"gcp-api-keys-accessors"` | no |
| api\_management\_project\_id | ID of the API Management Hub project, e.g. the `api_management_project_id` output of cf-organization. | `string` | n/a | yes |
| domain | Domain of the organisation's groups. | `string` | n/a | yes |
| environment\_tag\_key | ID of the `environment` tag key (`tagKeys/<id>`), e.g. the `environment_tag_key` output of cf-hierarchy. | `string` | n/a | yes |
| environment\_tag\_values | IDs of the `environment` tag values (`tagValues/<id>`) by folder name, e.g. the `environment_tag_values` output of cf-hierarchy. Only the secrets tagged `development` are readable by the API keys' accessors. | `map(string)` | n/a | yes |
| folders | The folders by folder name, e.g. the `folders` output of cf-hierarchy: `id`, the resource name (`folders/<id>`); `short_name`, the environment's short name, null for folders other than environments; `common`, whether it is the common environment. Each environment gets a Gemini API keys service account; the common environment's short name prefixes the resources' names and names its SREs group. | ```map(object({ id = string short_name = optional(string) common = optional(bool, false) }))``` | n/a | yes |
| kms\_key\_rotation\_period | Rotation period of the KMS key, in seconds with an `s` suffix; earlier key versions keep decrypting the values encrypted with them. | `string` | `"7776000s"` | no |
| region | Region of the KMS key and the secrets, part of their names. | `string` | `"europe-west4"` | no |
| sres\_group\_suffix | Suffix of the common environment's SREs group (`gcp-<common short name>-<suffix>`), encrypting the values of the API keys' secrets. | `string` | `"sres"` | no |
| tf\_bootstrap\_email | Email of the `tf-bootstrap` service account applying the module, e.g. the `tf_bootstrap_email` output of cf-bootstrap, decrypting the KMS-encrypted values of the API keys' secrets. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| api\_manager\_email | Email of the API keys manager service account, impersonated by the API keys' accessors. |
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
