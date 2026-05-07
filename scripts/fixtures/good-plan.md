# Good Plan Fixture

> Used by `rules-lint.yml` to smoke-test that `validate-done-criteria.py` passes on schema-conformant Done Criteria. Do not delete.

## Done Criteria

1. `file_exists scripts/validate-done-criteria.py` — validator script ships
2. `count_gte 9` approved verbs in the schema whitelist — verb count matches schema doc
3. `ci_check_passes rules-lint` on PRs — CI integration works
4. `byte_length_gte 200 guides/advanced/done-criteria-schema.md` — schema doc is not a stub
5. `tag_exists v1.4` — release ships
