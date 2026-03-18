## Available Pipelines

| Name | Description | Source | Steps |
|------|-------------|--------|-------|
| ship-feature | Full feature dev cycle: spec → implement → review → merge | stock | 6 |
| hotfix | Fast-path fix: diagnose → patch → test → deploy | stock | 4 |
| research-spike | Explore → prototype → document → decide | stock | 4 |

3 pipelines available (3 stock, 0 custom).

To run a pipeline:
  `/pipeline run ship-feature`

To create a custom pipeline:
  `/pipeline create <name>`

Stock pipelines are read-only. Copy to `.claude/pipelines/` to customize.
