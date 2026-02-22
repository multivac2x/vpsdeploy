## Description

[Provide a clear, concise description of the changes in this PR]

## Related Issues and Stories

[Link to any related issues or stories using `#` notation, e.g., "Fixes #123" or "Related to Story 2.3"]

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Test updates only
- [ ] Refactoring (no functional changes)

## Testing Performed

[Describe the testing you performed to verify your changes. Include:

- Commands run (e.g., `bash -n`, `shellcheck -x`, `./verify_epic2.sh`)
- Manual testing steps
- Any edge cases tested
- Idempotency verification (if applicable)]

### Test Results

```bash
# Example - replace with your actual test results
bash -n setup-vps.sh && echo "✅ Syntax OK"
shellcheck -x setup-vps.sh && echo "✅ Shellcheck OK"
./verify_epic2.sh 2>&1 | tail -20
```

## Checklist

- [ ] My code follows the bash style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have added tests that prove my fix is effective or that my feature works (if applicable)
- [ ] All new and existing tests pass (`bash -n`, `shellcheck -x`)
- [ ] I have updated the documentation accordingly (README, docs/, etc.)
- [ ] I have checked that my changes don't break existing functionality
- [ ] I have run `grep -l "\[ \]" docs/stories/*.md` and updated any affected stories
- [ ] My changes generate no new shellcheck warnings or errors
- [ ] I have added comments to my code, particularly in hard-to-understand areas
- [ ] I have checked for any hardcoded values and made them configurable if needed

## Screenshots / Logs

[If applicable, add screenshots or log output to help explain your changes]

## Additional Notes

[Add any additional information that reviewers should know, such as:

- Why certain design decisions were made
- Any known limitations or future improvements
- Dependencies on other PRs or changes]

---

**Reviewer Notes:**

- Please verify all acceptance criteria for related stories are met
- Ensure the changes are idempotent where appropriate
- Check that error messages are clear and helpful
- Validate that dry-run mode works correctly for any operational changes
