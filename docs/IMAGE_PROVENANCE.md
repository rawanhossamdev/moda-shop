# Asset provenance and publication rights — reviewed 2026-10-31

## Decision

**NO-GO pending the owner reviews below.** The five old unverified photos
and old Home capture have been replaced in the publication set. Originals remain
only in ignored build/rights-quarantine; they are not licensed or declared cleared.
No Git history has been initialized or published. Hashes establish identity, not
permission. AI generation alone is not treated as permission evidence.

## Latest owner clarification: statements versus verification

The following statements were supplied by the project owner, not independently
established by a license certificate or trademark search:

| Owner confirmation | What it establishes / does not establish |
|---|---|
| MODA was suggested during AI-assisted development and selected by the owner. | Documents the naming decision. It does not establish trademark availability, registration, exclusivity, non-confusion or permission in any market/category. No legal trademark clearance or search is claimed. |
| AI image generation was performed using the owner's own ChatGPT account. | Confirms account ownership and workflow as stated by the owner. It is not independent account verification and does not establish which terms apply to every output, rights in earlier inputs, or third-party/likeness rights. |
| Project design work was assisted by ChatGPT. | Records the owner's description of design assistance. It does not establish authorship of every element or clear rights in reference-derived material. |
| Approximately four or five copied/unknown-source images were used earlier and have now been replaced. | Consistent with the five specific retired PNGs independently matched below. The owner did not identify a source/author/license for the old bytes; those bytes are not cleared. |
| Open Fashion Figma was used as a reference during development. | Confirms reference use. It is not a license for protected assets or expression and does not establish whether any such material remains in the project. |

Independent current publication-candidate checks found:

- 415 files were eligible under the actual Git ignore rules; no .git exists in
  the application and therefore no local commit history was available to inspect.
- No .fig, .sketch, .xd, .psd, .ai, .eps or .svg design-source/export files, or
  standalone .ttf/.otf/.woff font files, were present in that candidate inventory.
- 201 raster/font asset candidates were inspected for recognizable embedded source
  markers such as Figma/Open Fashion and common stock-image services: none found.
  A marker/filename search cannot identify every renamed, recompressed or visually
  derived asset and is not an exhaustive similarity search.
- Asset/renderer/icon code and attribution references were reviewed. Current
  photos map to the generated-output manifests; geometric artwork maps to the
  local renderer/CC0 notice; UI icons map to Flutter/Cupertino references and the
  local footwear vector. No directly identifiable Figma artwork/image/icon import
  was found. This is a bounded repository finding, not a universal no-copy proof.
- Each of the five private PNG backups matched its retired SHA-256, and each
  public PNG differed. Neither these backup paths nor any matching retired bytes
  appeared anywhere in the publication candidates. The old Home screenshot's
  retired hash was also absent. Names reused for replacements do not mean the
  original photographs remain public.
- Five replacement records, all 94 catalog-photo hashes and the new Home capture
  matched their manifests; the four screenshots had no PNG text/EXIF metadata.

Thus **no remaining specific copied original was identified** in the proposed
public set. Broader input/design/name rights remain uncertain, not disproven or
cleared by this negative search. Private backups are deliberately retained only
under ignored build/rights-quarantine and must not be force-added to Git.

## Current Figma/reference-material check — 2026-10-31

The current read-only path check found no design-source files (.fig, .sketch,
.xd, .psd, .ai, .eps, .svg) or standalone font files. A text-marker search across
assets, source code and tools found no Figma/Open Fashion/source marker, excluding
the provenance and replacement records. The replacement record says no
legacy/reference/Figma image was submitted to create the new hero. Earlier
documented checks also found no directly identifiable Figma import among the
candidate assets. These are bounded filename/marker and repository-content
checks; they cannot rule out visually derived or renamed material, or determine
whether a UI element reproduces protected expression. No protected Figma material
was identified, but its absence is not independently proven. The owner must
review the actual publication set and confirm that no protected Figma assets or
copied reference materials remain; any identified material needs permission or
replacement.

## Five replaced files: exact paths and original findings

All five originals were pre-existing locally supplied PNGs. No original author,
source URL, license receipt, model release or reliable generation record was found.
They cannot be attributed to Figma or another creator from appearance alone.
**Redistribution permission for those original bytes could not be established.**

| Exact repository path | Current replacement and origin |
|---|---|
| assets/images/moda_banner.png | New text-only OpenAI image_gen still life; no external image inputs, people or faces. One self-reference edit used only that new output. Warm ivory chair/blazer/trousers/bag scene, 2172×724. |
| assets/images/knit_sweater.png | Lossless PNG encoding of assets/images/photography/knit-sweater_cream_front.jpg, an existing recorded OpenAI catalog output. |
| assets/images/wide_leg_trousers.png | Lossless PNG encoding of assets/images/photography/wide-leg-trousers_sand_front.jpg, an existing recorded OpenAI catalog output. |
| assets/images/tailored_blazer.png | Lossless PNG encoding of assets/images/photography/tailored-blazer_black_front.jpg, an existing recorded OpenAI catalog output. |
| assets/images/shoulder_bag.png | Lossless PNG encoding of assets/images/photography/shoulder-bag_black_front.jpg, an existing recorded OpenAI catalog output. |

The four product rasters remain 720×960: no crop, filter or resize. Paths and
product/variant/cart data are unchanged. The hero crop/decode was adjusted for its
new 3:1 ratio; layout, copy and colors remain. The
[replacement registry](../assets/images/PUBLICATION_REPLACEMENTS.json) records
old/new SHA-256 values, dimensions, source output filenames, exact hero prompts,
the no-external-input chain and permission limitations. Old bytes are rejected by
the publication audit even if renamed. No new LICENSE is created by this registry.

## Documented provider permission basis

Primary sources checked on the review date:

- [OpenAI Terms of Use: Content](https://openai.com/policies/terms-of-use/) assigns
  OpenAI's rights, if any, in output to the user, to the extent allowed by law.
  Input permissions, third-party rights and non-uniqueness remain limitations.
- [Services Agreement §§4.1–4.4](https://openai.com/policies/services-agreement/)
  provides corresponding customer output assignment and input/use responsibilities
  for business/developer services. It is not an exclusive-copyright or third-party
  clearance warranty.
- [Sharing/publication policy](https://openai.com/policies/sharing-publication-policy/)
  calls for review, attribution and clear AI disclosure. The catalog notice now
  explicitly says AI-generated imagery; gallery labels already identify it.

This establishes a **provider-side output-rights basis**, separately from the fact
of generation. It is not a CC0/open-source license or proof of this owner's
account/customer authority, nor permission for somebody else's input/output. Owner
confirmation of applicable account authority and input rights remains required.
Do not put private account information or credentials in the public record.

## Remaining 94 catalog photos

The [catalog manifest](../assets/images/photography/PROVENANCE.json) and
[edit history](../assets/images/photography/EDIT_HISTORY.json) identify 94 JPEG
outputs for 24 fictional products/46 colors. All SHA-256 hashes matched. All five
current contact sheets were visually reviewed. No identifiable retailer logo or
watermark was detected at review resolution; this is not an exhaustive similarity,
reverse-image or trademark clearance. Filenames/hashes do not prove earlier input
rights or account authority; owner confirmation remains necessary.

Generated human-model imagery particularly needs review: longline-coat_black_front,
tailored-blazer_camel_front, wide-leg-trousers_charcoal_front, and wrap-midi-dress
black_front/rose_front/rose_side/rose_detail JPEGs in assets/images/photography/.
Records describe fictional generated models; no real-person release or likeness
clearance is asserted. No identities were inferred. The new hero and four PNG
replacements contain no people.

## Other assets and evidence

| Group | Evidence and status |
|---|---|
| assets/images/catalog/*.png and drawing source | Existing catalog/LICENSE.md grants CC0-1.0 for geometric artwork and drawing source; tool/render_catalog_art.ps1 records the local drawing process. Preserve that existing grant; it does not license unrelated code/photos. |
| Material outline icons | lib/theme/moda_icons.dart references Flutter APIs. [Material's Apache-2.0 license](https://github.com/google/material-design-icons/blob/master/LICENSE) and [Flutter's license](https://github.com/flutter/flutter/blob/master/LICENSE) permit distribution under their conditions. SDK icon/font binaries are not copied into this source tree. Retain upstream notices in dependency/binary distribution. |
| Cupertino Icons dependency | [Upstream MIT notice](https://github.com/flutter/packages/blob/main/third_party/packages/cupertino_icons/LICENSE) permits redistribution with its notice requirement. No ownership is claimed. |
| Footwear outline vector | Locally drawn in lib/theme/moda_icons.dart; no third-party source reference found in drawing code. Owner authorship confirmation remains part of source approval. |
| assets/branding/moda-icon.png and Android launcher/splash rasters | tool/generate_branding.ps1 renders installed Times New Roman. [Microsoft's font FAQ](https://learn.microsoft.com/en-us/typography/fonts/font-faq) addresses logo/graphic sharing under its conditions. No system font file is bundled. This is a bitmap-output permission basis, not trademark clearance or proof of the underlying Windows/app license. Owner confirms legitimate font use and name/branding authority. |
| docs/screenshots/home.png | Refreshed from actual Flutter widget rendering with the new hero, 24-product synthetic catalog and mocked storage/auth, 720×1280. Not a new emulator capture or Figma mockup. Old capture quarantined. No account names/emails/addresses/tokens or PNG text/EXIF metadata. |
| catalog.png, product.png, variants.png | Existing emulator captures reviewed again: no private app data or PNG text/EXIF metadata. Their generated footwear images inherit provider/input conditions above. Screenshot capture grants no new underlying image rights. |

## Figma reference

The owner confirms that Open Fashion Figma was used as a reference during
development and that ChatGPT assisted the project design work. These statements
are owner confirmations, not independent legal verification. The
[Open Fashion community page](https://www.figma.com/community/file/1055151140671808467/open-fashion-free-ecommerce-ui-kit)
could not be retrieved because robots controls blocked access. “Free” in a title
is not a license. No Figma source file was found in the candidate inventory. That does not
establish independent authorship of every UI element. The owner must review and
confirm that no protected assets or copied reference materials remain, or supply
permission/replace any material found. No license or endorsement is inferred from
crediting this reference.

## Owner approvals still required

- AI image generation on the owner's own ChatGPT account is owner-confirmed, not
  independently verified. Owner review remains for applicable output terms,
  rights in earlier reference inputs, and generated model imagery/outputs. Do not
  assume a new blanket grant.
- Open Fashion Figma reference use and ChatGPT design assistance are
  owner-confirmed, not independent legal findings. No direct import was
  identified by repository checks; owner must review that no protected assets or
  copied reference materials remain. If any are found, provide permission or
  replace them. No Figma license is inferred.
- The AI-suggested, owner-selected MODA naming origin is now recorded. Remaining
  brand/name conflict or trademark questions require owner review; no jurisdictional,
  goods/services, registration or similarity clearance was performed. Confirm
  legitimate font use and local artwork authorship separately.
- Approve the replacement appearance and final distribution. If confirmations
  cannot be made, replace the affected content instead of marking it cleared.

Source remains review-only with no new software reuse license. Third-party terms,
applicable-law/GitHub rights and existing separate CC0 grants remain intact. No
blanket legal clearance is claimed. See the [release checklist](RELEASE_CHECKLIST.md).

**Recommendation: NO-GO pending the narrower remaining owner rights/risk sign-off
and final publication approval.** This is not a finding that a particular copied
Figma asset or retired photograph remains, nor a claim that a formal trademark
registration is required for this portfolio. Known-original removal is verified;
unresolved account/input/design/brand matters must not be silently marked cleared.
