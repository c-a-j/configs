# Upstream Grill Me skill

- Repository: https://github.com/mattpocock/skills
- Commit: `383b6a06d59c4ce0ffcb14112bfd91265a86cf91`
- Source: [skills/grill-me/SKILL.md](https://github.com/mattpocock/skills/blob/383b6a06d59c4ce0ffcb14112bfd91265a86cf91/skills/grill-me/SKILL.md)
- SKILL.md SHA-256: `74147eb6010a65957efef2b9e0f0b3ff935c1def7fc117697151b1d0f3610556`
- LICENSE SHA-256: `0e7ac423bf2c6e223b7c5b156f8cf72da49d748e56a1641402c31f22ad07dbb5`

`SKILL.md` and the repository's MIT `LICENSE` are copied verbatim from this
commit. This self-contained version works with Pi's native skill loading. The
later catalog entry delegates to a separate `grilling` skill through a `Skill`
tool, which Pi does not provide; it is not used here.

Pi discovers `/skill:grill-me`. The local native prompt template
`prompts/grill-me.md` supplies `/grill-me` as a convenience shortcut by asking
the model to read and follow the available skill. It is not an executable
extension and does not change permissions.

Setup installs only these Markdown and license files, not the upstream skill
collection or executable code. Updates are explicit and never fetched during
setup. To update, review a new upstream commit, replace the vendored files,
update this provenance record and hashes, and rerun setup.
