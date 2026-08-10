# Tutorial Studio setup

The implementation never creates networking or bindable instances at runtime. Create these instances in Studio before publishing:

| Explorer hierarchy | Type | Used by | Direction / purpose |
| --- | --- | --- | --- |
| `ReplicatedStorage > TutorialRemotes` | `Folder` | `TutorialService`, `TutorialController` | Container only. |
| `ReplicatedStorage > TutorialRemotes > GetTutorialState` | `RemoteFunction` | `TutorialService`, `TutorialController` | Client → server request; server → client authoritative snapshot response. |
| `ReplicatedStorage > TutorialRemotes > TutorialAction` | `RemoteFunction` | `TutorialService`, `TutorialController` | Client → server prompt/Continue/inventory action; server validates and returns the resulting snapshot. |
| `ReplicatedStorage > TutorialRemotes > TutorialStateChanged` | `RemoteEvent` | `TutorialService`, `TutorialController` | Server → client authoritative state synchronization after a transition. |
| `ServerStorage > TutorialProgressAPI` | `BindableFunction` | `TutorialService` and gameplay server scripts | Server → server validated objective reporting. |

Place the source files as follows:

* `TutorialConfig` → `ReplicatedStorage > TutorialConfig` (`ModuleScript`).
* `TutorialService` → `ServerScriptService > TutorialService` (`Script`).
* `TutorialController` → `StarterGui > TutorialUI > TutorialController` (`LocalScript`).

The controller uses the existing authored UI under `TutorialUI > MainFrame`, and it expects `NewComer`, `Part1` through `Part8`, their specified buttons/labels, and `MainFrame.Visible = true`. Individual tutorial frames should remain invisible in Studio.

## Existing indicators used

All arrows remain client-only. The controller searches for the tycoon through `OccupiedPlot` and verifies its `Owner` value before enabling an arrow.

* `Workspace > Tycoons > Tycoon1..Tycoon6 > ... > Pads > Pad1 > Tutorialindicator`
* `Workspace > Tycoons > Tycoon1..Tycoon6 > ClaimEarnings > ... > Info2 > Tutorialindicator`
* `Workspace > NPCS > AfraiC4t > Head > Tutorialindicator`
* `Workspace > NPCS > Itsmefeje > Head > Tutorialindicator`

No indicator is created dynamically. A temporarily missing indicator is polled without blocking progression, and its animation is cancelled and original `StudsOffset` restored whenever the stage changes.

## Persisted data

`TycoonDataHandler` stores a `Tutorial` table in the existing player record with: `Answered`, `Skipped`, `Active`, `Stage`, `Completed`, `InventoryOpened`, `CarPlaced`, `EarningsClaimed`, `TransferComplete`, `ATMWithdrawn`, `LocalCarPurchased`, and monotonic `Revision` fields. `ForceWipe` restores the whole table to new-player defaults, so existing data reset tooling also resets tutorial eligibility.
