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

Inbox entries retain a permanent consumed identity in the mailbox key. Claim grants and their unresolved profile markers commit together. The marker can be forgotten only after the mailbox durably removes/consumes the entry. Active and premium craft jobs, and car-transfer outboxes, retain stable delivery IDs across retries. Paid craft skips persist a receipt-to-job binding before delivery; retrying a completed skip never completes a new job. Sender and receiver rank grants use separate idempotent identities, and do not force a save in the middle of the caller's profile transaction.

Offline earnings freeze an award before Inbox enqueue, and consume that frozen award only after delivery. An older pending award stays frozen across visits; new offline income waits until that award is consumed. Premium cancellation returns to the same frozen award and never adds it to tablet carry a second time. Receipt double-claim feedback comes from receipt finalization, rather than the purchase-prompt completion event.

`HotbarPersistenceEvent` is created by the server when absent. The client sends six canonical owned car keys and a request ID; the server validates/rate-limits the request and returns the accepted keys with that ID. Import the paired inventory client and data handler.

The added profile/mailbox fields are additive. Do not run an older server build that strips new outboxes, ownership IDs, frozen claims, or consumed identities while testing this build. Back up test data before rollout and use a separate test universe.

## Automated checks

`Release safety` builds a pinned Luau compiler/runtime, compiles all tracked game scripts, and runs deterministic service regressions. The Inbox regression executes the actual repository service with mocked DataStore and grant APIs, covering:

- accepted and declined entries cannot be replayed by re-enqueue;
- a failed grant releases its mailbox claim lease;
- a committed grant followed by failed mailbox cleanup remains exactly-once on retry;
- invalid/unknown IDs do not trigger claim writes;
- delivery retries after an injected DataStore outage;
- car identity and paid variant survive delivery.

The offline suite executes the actual service through freeze/save outages, reconnect recovery, premium binding and cancellation, legacy paid delivery, and zero awards. Craft tests execute both tiers' actual delivery and skip handlers, including failed binding/completion saves and old receipt retries during a new craft. Base migration tests execute both implementations, checking full preflight and rollback after a mid-move error. A profile reward regression executes the promo redemption handler with concurrent spending during a failed save, checking that the reward marker and later spending survive together.

Run with:
```sh
python3 tests/run.py --compiler /path/to/luau-compile --runtime /path/to/luau
```

Compilation and mocks cannot validate Studio assets, replication, MarketplaceService receipts, Roblox throttling, or engine lifecycle ordering.

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
- **Offline migration:** existing normal offline deliveries used amount-based IDs and cannot always be reconstructed. Rehearse pending legacy claims before rollout. An ownership lookup outage followed by an early server crash can still lose an interval before its first freeze; automatic preparation reduces that window.
- **Final saves:** retries are best effort within Roblox's shutdown lifetime. Service requests may remain throttled longer than that lifetime; an abrupt crash can lose unsaved gameplay since the last durable autosave. Test the shutdown budget with production-sized profiles.
- **Historical data:** new stable IDs and tombstones cannot reconstruct gifts or dupes that already occurred, or prove a previously consumed legacy Inbox entry. Audit suspicious legacy accounts separately.
- **Modal ownership:** conversation generations and missing-UI cleanup reduce stuck controls. A shared modal/focus manager across all menus remains an architectural follow-up.
- **Runtime assets:** this export does not include the place, GUI tree, every Remote object, animations, or models. Missing/misconfigured Studio instances remain a release blocker even when scripts compile.
