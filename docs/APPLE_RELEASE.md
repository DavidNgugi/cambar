# Apple release setup

The GitHub release workflow signs CamBar with a Developer ID certificate and
notarizes the DMG before publishing it. Add these repository secrets before
creating the next version tag:

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64-encoded Developer ID Application `.p12` export |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_SIGNING_IDENTITY` | Full identity, e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER` | App Store Connect issuer ID |
| `APPLE_API_PRIVATE_KEY_BASE64` | Base64-encoded App Store Connect `.p8` private key |

Create the API key in App Store Connect under **Users and Access → Integrations → App Store Connect API**. Create the Developer ID Application certificate in the Apple Developer account, export it as a password-protected `.p12`, and keep both the certificate and private key out of the repository.

Until these secrets are configured, local builds continue to use ad-hoc
signing and macOS may show the Gatekeeper warning.
