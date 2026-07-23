# Changelog

All notable changes to the Tabnine plugin for opencode are documented here. This
product is in beta. Versions follow the `tabnine-opencode` release numbering.

## 0.4.0 (beta)

First public beta.

- Managed, self-contained install of opencode with the Tabnine plugin, launched as `tabnine-opencode`. Installers for macOS, Linux, and Windows (x64 and arm64).
- Sign in with your Tabnine account, from the command line (`tabnine-opencode auth login`) or the interactive TUI (`/connect`). Personal access tokens and environment-variable authentication (`TABNINE_TOKEN`) are supported for scripts and CI.
- Model list restricted to the models your organization enables through Tabnine (the provider is locked to `tabnine/*`).
- Two built-in Tabnine MCP servers, and support for adding your own.
- Your organization's Tabnine governance is enforced (agent guidelines, tool and MCP governance, model availability, quota, and license).
- Proxy and custom certificate-authority support for restricted networks.
- Version reporting (`tabnine-opencode --version`) and per-session debug logs.

For installation and usage details, see https://docs.tabnine.com.
