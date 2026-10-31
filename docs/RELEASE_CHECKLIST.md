# Public release checklist

Publication is paused for owner review. No Git initialization, remote creation, commit, push or public deployment has been performed by this preparation pass.

## Prepared

- [x] Card names/prices enlarged, aligned and overflow-safe.
- [x] Repeated sample suffix replaced by visible demo-catalog disclosure.
- [x] Swipeable category row retained with accessible previous/more controls.
- [x] Photography, variants, galleries, cart/recovery, checkout and branding preserved.
- [x] Root README, backend setup, portfolio case study, public architecture and provenance documentation.
- [x] Git exclusions for private configuration, local data, exports, logs, keys, dependencies, build output and private source-cache manifests.
- [x] Placeholder-only backend `.env.example`; delivery and online payments disabled in the documented setup.
- [x] Existing Gradle wrapper files included in the source set; no wrapper/build/SDK version changed.
- [x] Owner chose review-only public source with no new software reuse license; README/PORTFOLIO notices preserve separate component rights. No LICENSE was added.
- [x] Record owner confirmations: AI image generation used the owner's own ChatGPT account; Open Fashion Figma was used as a development reference; ChatGPT assisted project design; MODA was AI-suggested/owner-selected; product imagery was ChatGPT/Codex-assisted; earlier copied/unknown images were replaced. These are owner statements, not independent legal verification or blanket rights clearance.

## Owner decisions before publication

- [x] Retire the five original unverified photos and old Home capture from publication; replace at stable paths and record old/new hashes and provider permission evidence. Original bytes remain only in ignored quarantine.
- [x] Review OpenAI output-rights/publication terms, icon licenses and Microsoft bitmap font-output guidance; record conditions and limits in image provenance. AI generation alone is not clearance.
- [x] Refresh Home with the replacement hero and explicit AI disclosure; visually review the capture, pass 51 focused UI/shopping tests, capture test, analysis and five audit regression tests. Verify replacement/catalog hashes and exclusion of quarantined bytes.
- [x] Recheck 415 candidates, 201 asset files, icon/renderer sources and exact retired hashes: no identifiable Figma import/design file, retired bytes or private backup included. Negative searches are not proof against every renamed/derived copy.
- [ ] Owner reviews applicable generation terms, rights in earlier reference inputs, and generated model imagery/outputs. Account ownership is owner-confirmed, not independently verified, and does not settle these rights.
- [ ] Owner reviews the publication set and confirms no protected Figma assets or copied reference materials remain. The bounded candidate search found no design-source files, recognizable source markers, or directly identifiable import; it cannot rule out renamed/derived material or copied protected expression. Provide permission or replace any material identified. No Figma license is inferred.
- [ ] Owner reviews unresolved MODA name/branding conflicts and confirms legitimate font/local artwork use. Naming origin/selection is confirmed; trademark availability or clearance is not.
- [x] Review the four screenshots for account/customer information and embedded text/EXIF metadata: none found. This does not clear depicted image rights.
- [ ] Owner confirms accurate authorship/copyright attribution and the existing separate CC0 drawing-source grant; no broad reuse license is being granted by this review.
- [ ] Choose a GitHub account/repository and a GitHub-provided no-reply commit email if desired.
- [ ] Re-run all final checks and the candidate/staged audit after any edits.
- [x] Clean candidate-copy Android debug build passed. SDK/package caches are shared; this is not a cache-cold or cross-platform build certification.
- [x] Clean candidate-copy dependency installation, Prisma generation/validation, all migrations on a disposable empty PostgreSQL cluster, seed twice, DB/API checks, 169 Flutter tests and 82 backend tests passed. Existing database/configuration were not modified.
- [ ] Decide whether to provide a safe verified-account demonstration outside source control; the default email-disabled setup intentionally gates new-account COD checkout.
- [ ] Explicitly approve publication before running any remote creation/push command.

## Rights decision and remaining publication gate

The owner chose **no new software reuse license**, not an open-source license.
No LICENSE is to be added. Applicable-law rights, GitHub's platform terms and
pre-existing separately licensed components remain unaffected. Dependency/icon
licenses and image permissions are separate; ownership of third-party assets is
not claimed. The existing geometric-artwork/drawing-source CC0 notice is retained.
See [GitHub's licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

**NO-GO pending the remaining owner rights/risk sign-off and final publication
approval**, not because a specific remaining copied asset was identified. Account
ownership, Figma reference use and ChatGPT design assistance are recorded as owner
confirmations in [image provenance](IMAGE_PROVENANCE.md), not independent legal
verification. Earlier input/model, no-copied-reference-material, name/branding,
font/artwork authorship and attribution questions remain for owner review. The five original
unknown-source photos and their Home capture have now been replaced. Their old
bytes are not cleared or publishable. Provider assignment, third-party licenses
and font-output guidance are documented; none substitutes for the missing owner
confirmations. Do not initialize Git or publish until those confirmations and
final publication approval are supplied.

## Final checks

```text
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
node tool/audit_publication.mjs
node --test tool/audit_publication.test.mjs
node tool/verify_asset_provenance.mjs
```

From backend: `npm test`, `npm run check`, `npm run prisma:validate`, `npm audit`
(the advisory check needs network access). After approved Git initialization/staging,
run `node tool/audit_publication.mjs --staged` and `git diff --cached --check`. Stop
on any audit finding; do not commit or push a failing source set. Ignore rules do
not remove files already tracked in Git.

See [publication report](PUBLICATION_REPORT.md) for results, limitations and step-by-step PowerShell publication commands to run only after approval.
