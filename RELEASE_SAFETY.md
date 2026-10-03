# Release safety changes and verification

This branch hardens the live game's existing systems. Import matching server and client scripts together; the repository is an export of Studio scripts, not a Rojo project. Script names and their documented Studio locations remain the installation guide.

## What changes for players

- Accepted player-to-player car gifts arrive in **Inbox**. Removing the sender's car and recording a delivery outbox happen in the sender's profile before delivery. Inbox can retry delivery after a crash; the receiver acquires the car and rank progress when claiming it.
- Crafted cars arrive in Inbox. Workshop dialogue now tells players where to claim them.
- Sell-all asks the server for a price and confirmation token. Changing the quoted inventory invalidates the confirmation instead of selling additional cars the player did not approve.
- When a save or request has an uncertain result, the UI asks the player to check the result. A client timeout does not prove a server operation failed.
- An incomplete data restore blocks gameplay and saving. A missing asset or oversized legacy inventory needs repair; it must not be silently saved as a smaller inventory.

## Review map

Severity describes the original failure's impact. Import each row's server/client changes together.

| Priority | Problem and affected scripts | Fix and interaction to review |
| --- | --- | --- |
| Critical | Incomplete restores and count-based anti-wipe fallbacks could overwrite or resurrect cars (`TycoonDataHandler`, `PadController`). | Block incomplete loads/snapshots; preserve unique IssuedIds; save legitimate empty locations; remove the exact respawn mirror. Review inventory, placement, sacrifice, selling and gifts together. |
| Critical | A durable reward followed by an uncertain save/cleanup could be delivered twice (Inbox, car gifts, crafts, offline earnings, Lucky Spin). | Retain profile journals until durable Inbox consumption; save stable job/outbox identities before cross-key delivery; retain accepted effects after uncertain saves. Gift acquisition and craft rank progress now happen on Inbox acceptance. |
| High | Gift intent expiry/replacement and failed lookups could change the recipient of a paid receipt (`GiftIntentHandler`, `ReceiptRouter`). | Bind and save the original intent/target; match receipt identity when clearing it; retry on unavailable intent reads. Review all gift product families and legacy pending receipts. |
| High | Sell-all confirmation could sell inventory different from the player's quote (`SofhiaSellService`, `SofhiaDialogueLogic`). | Server quote tokens bind price, instances, ownership IDs and variants; expired/changed inventory rejects the sale. Both sides use the new quote protocol. |
| High | Partial base migrations and stale rollback could lose occupancy or overwrite newer state (base, pad, rebirth and skin services). | Validate every move before applying; synchronously restore links/pivots on application failure; retain accepted state on uncertain persistence. Animation origins follow migrations. |
| High | Unready/closing state, unresolved ownership and retry callbacks could mutate incomplete profiles (shops, rewards, ownership and rank). | Require readiness at mutating boundaries; distinguish unknown ownership from resolved false; coalesce/retry lookups; close partially loaded subsystem sessions on load failure. |
| Medium | Blocking global lookups, nondeterministic shop ordering and unpaid elapsed time affected scale and consistency (global boosts, shops, economy). | Cached nonyielding global state, background refresh/backoff, sorted pools and elapsed-time accrual. Existing same-rotation stock may change once when sorted ordering deploys. |
| Medium | Client lifecycle errors could leave stale callbacks, animations, camera/controls or purchase loaders active (NPC dialogues and client effects). | Generation checks, tracked cleanup, timeouts and server-confirmed purchase feedback; shorter dialogue with distinct character voices. A shared modal manager remains a follow-up. |
| Medium | Client hotbar attributes were not an authoritative persistence protocol (`inventory gui`, data handler). | Server validates six owned variant-aware keys and acknowledges revisions; defer changes during respawn. Existing tools must have canonical IDs. |

## Persistence and delivery contracts

Owned cars carry a stable `IssuedId` through Tools, StarterGear mirrors, placed models, saved inventory/layout, and Inbox payloads. Variant ownership is stored separately from the canonical base car ID. A mirror is another representation of the same car, not a second owned car.

Subsystem loads must acknowledge success before the profile is Ready. Mutating handlers check Ready and closing state. Saves collect loaded subsystem state; shutdown waits for active and already-closing profiles and completes final-save notifications after all attempts.

Inbox entries retain a permanent consumed identity in the mailbox key. Claim grants and their unresolved profile markers commit together. The marker can be forgotten only after the mailbox durably removes/consumes the entry. Active and premium craft jobs, and car-transfer outboxes, retain stable delivery IDs across retries. Paid craft skips persist a receipt-to-job binding before delivery; retrying a completed skip never completes a new job. Sender and receiver rank grants use separate idempotent identities, and do not force a save in the middle of the caller's profile transaction. Ownership grants and receipt/claim markers remain synchronous; potentially yielding index updates run in a later scheduler turn.

Offline earnings freeze an award before Inbox enqueue, and consume that frozen award only after delivery. An older pending award stays frozen across visits. Later visits do not add offline income while that award remains pending; saved tablet carry remains separate. This policy must be reviewed before release. Premium cancellation returns to the same frozen award and never adds it to tablet carry a second time. Receipt double-claim feedback comes from receipt finalization, rather than the purchase-prompt completion event.

`HotbarPersistenceEvent` is created by the server when absent. The client sends six canonical owned car keys and a request ID; the server validates/rate-limits the request and returns the accepted keys with that ID. Import the paired inventory client and data handler.

The added profile/mailbox fields are additive. Do not run an older server build that strips new outboxes, ownership IDs, frozen claims, or consumed identities while testing this build. Back up test data before rollout and use a separate test universe.

## Previous validation

Before the automation files were removed, [checks on commit `58a6aefd`](https://github.com/fejelude/DreamGarageTycoon/actions/runs/37094163425) compiled all 169 Luau files and passed six regression suites covering Inbox, crafts, base migration, offline earnings, ownership and profile rewards.

The workflow and test harness are no longer included in this branch. These results describe the earlier checked commit; this branch does not run those checks automatically.

Compilation and mocked tests cannot validate Studio assets, replication, MarketplaceService receipts, Roblox throttling or engine lifecycle ordering. Complete the Studio release gate below before publication.

## Studio release gate

Use a published test universe with separate DataStores and at least two clients. Check the server and client output for errors.

1. **Ownership round trips:** last-car placement/pickup, equip/unequip, death/respawn, normal/exclusive copies of the same base car, Toyota Hilux aliases, rejoin, and accepting a gifted car. Count unique IssuedIds in inventory plus layout. Verify mirrors are never additional cars.
2. **Save failures:** inject failures before and after UpdateAsync commits, exhaust retries, remove a player during an active save, and invoke shutdown with profiles already closing. Rejoin and compare currency, inventory, pads, rank and pending earnings. Verify failed restores never become Ready or save default state.
3. **Session contention:** join two servers with the same profile in a controlled test. Verify the second cannot overwrite the first, lease loss blocks mutations, and an expired session can recover.
4. **Delivery recovery:** stop a server after sender removal/outbox save, after enqueue, after receiver grant, and before mailbox acknowledgement. Repeat with crafts and offline awards. A delivery must grant once, with its original variant and rank progress.
5. **Purchases:** test self and gift receipts, duplicate/reordered receipts, offline recipients, buyer disconnect, cancelled prompts, ownership lookup outages, full inventory, Inbox-full retries, premium craft cancellation, and double offline claim feedback. Verify unknown gift intent reads never silently change the recipient.
6. **Inventory consent:** request sell-all, then acquire, place, sell, gift, or respawn a quoted car before confirmation. The server must reject the changed quote. Verify placed cars are excluded.
7. **Bases and animation:** downgrade with missing destination pads; verify no partial moves. Trigger application errors and confirm synchronous rollback. Migrate placed cars and check that client animation follows the new base frame.
8. **Client lifecycle:** remove/stream out an NPC mid-conversation, omit a GUI label/button, respawn during a callback, rapidly show/hide purchase loading, fail teleport initialization, and repeat AFK entry/exit. Movement, camera and UI must recover.
9. **Load:** simulate the intended maximum players and placed cars. Add NPCs, spam malformed remote requests, and profile server/client work and DataStore budgets. Measure global-event outages without blocking economy ticks.

## Remaining release decisions and risks

These need explicit product policy or further integration work; this PR does not establish that the game is ready to publish.

- **Limited paid products:** expired/sold-out receipts and offline limited/slot/skin gift fulfillment need a deliberate compensation or durable alternative-delivery policy. Existing unresolved receipts remain retryable; do not acknowledge them without delivering value.
- **Already-satisfied paid skips:** a playtime skip bought when rewards are already unlocked, or which becomes redundant while a prompt is open, can still provide no benefit. A credit/substitute policy is required.
- **Inventory ceiling:** new grants must not overflow the persistence ceiling. Existing oversized saves fail closed for manual repair. Designing overflow storage or upgrading the data format is separate work.
- **Ambiguous purchase prompts:** Roblox receipts identify products and purchases, not the originating UI prompt. Bound/purchased gift contexts are retained, but a crash before the prompt-completion event persists can require reconciliation. Do not replace unresolved paid intent with another recipient.
- **DataStore size:** permanent Inbox consumed identities, craft receipt bindings, and retained unresolved journals grow. Monitor serialized size and design archival/sharding before reaching Roblox's key-size limit. Pruning unresolved identities by a recent-count window reintroduces replay.
- **Transaction isolation:** keeping accepted effects on uncertain writes avoids stale absolute rollback. This is not a universal transaction scheduler across every gameplay system; stress-test overlapping mutations and follow up on remaining shared-state writers.
- **High — offline checkpoint and pending-award policy:** an unrelated save can advance `LastOfflineAt` before the first award freezes while ownership services are unavailable. A crash during that window can lose the preceding offline interval. Preserve a durable interval snapshot or gate gameplay/saving until preparation completes; test this before publication. Keeping an older award pending also suppresses later visits' offline income. That is the current behavior, and needs an explicit product decision or a queue of distinct frozen awards.
- **Offline migration:** existing normal offline deliveries used amount-based IDs and cannot always be reconstructed. Rehearse pending legacy claims before rollout.
- **Final saves:** retries are best effort within Roblox's shutdown lifetime. Service requests may remain throttled longer than that lifetime; an abrupt crash can lose unsaved gameplay since the last durable autosave. Test the shutdown budget with production-sized profiles.
- **Historical data:** new stable IDs and tombstones cannot reconstruct gifts or dupes that already occurred, or prove a previously consumed legacy Inbox entry. Audit suspicious legacy accounts separately.
- **Modal ownership:** conversation generations and missing-UI cleanup reduce stuck controls. A shared modal/focus manager across all menus remains an architectural follow-up.
- **Runtime assets:** this export does not include the place, GUI tree, every Remote object, animations, or models. Missing/misconfigured Studio instances remain a release blocker even when scripts compile.


## Join startup and sync diagnostics

The data-load kick is an initialization safety failure, not an anti-cheat verdict. The data handler now waits up to 60 seconds for all seven shop/rank persistence callbacks before acquiring a profile lease. Each provider publishes `PersistenceReady=true` only after installing its callback. Cleanup skips unready callbacks, avoiding an indefinite Invoke wait after failed startup. Genuine failed restores still cannot become Ready or overwrite a profile with defaults.

Sync these eight scripts together: `TycoonDataHandler`, `LocalShopService`, `UncommonShopService`, `RareShopService`, `EpicShopService`, `LegendaryShopService`, `MythicalShopService`, and `RankService`. Run exactly one enabled server Script for each service; keep required server ModuleScripts such as `InboxService` in ServerScriptService. GitHub exports source text, not Explorer instances. In particular, rank bindables/remotes and ReplicatedStorage > BindableFunctions > SkipLegendaryCraftFunction / SkipMythicalCraftFunction must exist with the correct classes.

For a remaining join failure, capture server Output beginning with `[TycoonDataHandler] Player initialization failed`. This includes a traceback and underlying shop/rank error. Startup timeouts list the providers that never became ready. Inspect earlier errors from those scripts and their required instances. In Studio, also verify the published test place's DataStore access settings. Do not change the production store name or bypass validation to work around a missing dependency.

Manual checks for this change: delay a shop's startup, join, and confirm WaitingForServices transitions to Ready without a kick; omit a provider and confirm a bounded setup failure naming it without a profile write; leave during the startup wait and confirm no lease is acquired; cause a shop Load callback to error and confirm Output preserves the cause and the profile is never saved as defaults. This patch was inspected statically; Roblox Studio runtime verification is still required.
