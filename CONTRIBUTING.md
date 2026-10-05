# Contributing to Open-TRAFFIQX-Client-for-Delphi

Thank you for your interest in contributing to **Open-TRAFFIQX-Client-for-Delphi**.

Bug reports, test cases, documentation improvements and pull requests are welcome.
Please read the following guidelines before submitting code.

By submitting a pull request or other contribution, you agree to the contribution licensing terms described below.

## Project scope

Open-TRAFFIQX-Client-for-Delphi is a reference implementation for connecting desktop software to the TRAFFIQX Invoice API and the DATEV E-Rechnungsplattform, including:

* the Delphi client library (`client/Delphi/intf.TRAFFIQX*.pas`): login, token refresh, revoke, introspection, inbox, outbox, upload, status and download;
* the technical HTTP log and token protection units;
* the VCL sample project;
* the PHP OAuth2 broker (`OAuth2-Broker/`) for the Authorization Code flow with PKCE;
* the integration guide (`Integration.md`) and the DATEV acceptance checklist (`Abnahme.md`).

## Before submitting a pull request

Please:

1. Keep changes focused on a single issue or feature where possible.
2. Avoid unrelated formatting or whitespace changes.
3. Follow the style of the surrounding source code.
4. Add or update tests for functional changes where practical.
5. Make sure the sample project still builds.
6. Clearly describe what was changed and why.

Changes affecting API calls, the OAuth2 flow or the broker should, where applicable, be tested against the DATEV sandbox. Please state in the pull request which calls and which environment you tested.

If a change affects the DATEV acceptance requirements (for example token handling, the HTTP log or error display), please update `Abnahme.md` and `Integration.md` accordingly.

## Secrets and test data

Never include any of the following in a commit, pull request, issue or log excerpt:

* client IDs and client secrets, broker API keys, the contents of `.env` or of your local broker configuration (`OAuth2-Broker/config/`);
* access, refresh or ID tokens, authorization codes or session IDs;
* unredacted HTTP logs (for example from `client/http-log/`);
* real invoices, TRAFFIQX IDs or personal data of customers.

Use synthetic invoices and redacted excerpts. If you accidentally published a secret, rotate it immediately and let us know.

## Security

Changes to the broker or to token handling must not weaken the existing protections, in particular PKCE, the `state` check, the redaction of secrets in the HTTP log and the API key check of the broker.

Please report vulnerabilities privately to [info@landrix.de](mailto:info@landrix.de) with the subject `[Security] Open-TRAFFIQX-Client-for-Delphi: short description` instead of opening a public issue.

## Compatibility

Changes that intentionally break the public API of the Delphi units or the broker endpoints should be discussed before implementation.

Please avoid introducing dependencies on third-party Delphi packages in the library units. The broker targets PHP 8.2 or newer.

## Source encoding

Please do not convert existing files to another encoding or other line endings as part of unrelated changes.

## Comments and documentation

Existing German or English comments do not need to be translated merely for consistency.

New public APIs should contain enough documentation to make their intended use and any relevant DATEV or TRAFFIQX restrictions understandable.

## Licensing of the project

Open-TRAFFIQX-Client-for-Delphi is dual-licensed.

Users may use the project under either:

1. the **GNU General Public License version 3 or later (GPL-3.0-or-later)**; or
2. the **Landrix Software Commercial License**.

The commercial license allows the library to be used as part of proprietary applications without the copyleft requirements of the GPL.

## Licensing of contributions

To preserve this dual-licensing model, contributions must be available for use under both licensing options.

By intentionally submitting a contribution for inclusion in Open-TRAFFIQX-Client-for-Delphi, you agree to the following terms:

You retain the copyright in your contribution.

You grant **Landrix Software GmbH & Co. KG** a perpetual, worldwide, non-exclusive, irrevocable, royalty-free license to:

* use,
* reproduce,
* modify,
* prepare derivative works of,
* publicly display,
* publicly perform,
* distribute,
* sublicense, and
* otherwise incorporate

your contribution, in source or binary form, as part of Open-TRAFFIQX-Client-for-Delphi and related versions of the project.

This license includes the explicit right to distribute and sublicense your contribution:

* under the GNU General Public License version 3 or any later version;
* under the Landrix Software Commercial License; and
* as part of commercial or proprietary distributions of Open-TRAFFIQX-Client-for-Delphi offered by Landrix Software.

This grant does **not** transfer ownership of your copyright to Landrix Software.

## Patent license

Where you own or control patent claims that would necessarily be infringed by your contribution alone or by its combination with the project as submitted, you grant Landrix Software and recipients of the contribution a perpetual, worldwide, non-exclusive, royalty-free patent license to make, use, offer for sale, sell, import and otherwise use the contribution as part of the project.

This patent grant applies only to patent claims that you have the right to license.

## Your authority to contribute

By submitting a contribution, you represent that:

* you created the contribution yourself or otherwise have the legal right to submit it under these terms;
* the contribution does not knowingly include code or other material that you are not authorized to provide;
* you have the authority to grant the rights described above.

If your contribution was created as part of your employment or on behalf of a company or other organization, you are responsible for ensuring that you are authorized to submit it under these terms.

Please do not submit code copied from another project unless its license is compatible with this project and its origin and license are clearly identified.

## Third-party code

If a contribution contains or is derived from third-party code, please state this clearly in the pull request and provide:

* the original project or source;
* the copyright holder, where known;
* the applicable license;
* a link to the original source where possible.

Do not submit GPL-only third-party code if Landrix Software would not also have the right to include that code in the commercially licensed version of the project.

Permissively licensed code, such as code under the MIT, BSD or Apache License 2.0, may be acceptable, but applicable attribution and redistribution requirements must be preserved.

## Automated or AI-assisted contributions

Code created with automated development tools or generative AI may be submitted, but the contributor remains responsible for the contribution.

In particular, you must ensure that:

* you have the right to submit the resulting code;
* no incompatible third-party code has been reproduced;
* the contribution has been reviewed and tested;
* the contribution complies with the licensing terms above.

Automated generation does not remove the contributor's responsibility for correctness, security or licensing.

## Pull request acceptance

Submission of a pull request does not guarantee that it will be merged.

Landrix Software may request changes, additional tests or documentation before accepting a contribution.

Once a contribution has been accepted into the project, the rights granted under the **Licensing of contributions** section are irrevocable.

## Questions

If you are unsure whether a contribution can be submitted under these terms, please open an issue before submitting the code or contact:

**Landrix Software GmbH & Co. KG**
[info@landrix.de](mailto:info@landrix.de)
