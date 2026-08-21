# Lucky Spin Studio Setup

The scripts deliberately do **not** create networking instances at runtime. Create this hierarchy in Studio before publishing:

```text
ReplicatedStorage
├─ LuckySpinConfig (ModuleScript; source from `LuckySpinConfig`)
└─ LuckySpinRemotes (Folder)
   └─ RequestSpin (RemoteFunction)
```

- `StarterPlayer > StarterPlayerScripts > LuckySpinClient` invokes `RequestSpin` with no arguments.
- `ServerScriptService > LuckySpinService` receives the request, rolls the reward, commits it through `ServerStorage > TycoonAdminAPI`, and returns only the already-granted result.
- No client-to-server reward, car, currency, rarity, or rotation value is accepted.

Install the other sources at these locations:

```text
ServerScriptService
├─ LuckySpinService (Script)
├─ ReceiptRouter (existing Script; updated source)
└─ TycoonDataHandler (existing Script; updated source)

StarterPlayer
└─ StarterPlayerScripts
   ├─ LuckySpinClient (LocalScript)
   └─ MusicPlaylistManager (existing LocalScript; updated source)

ReplicatedStorage
├─ LuckySpinConfig (ModuleScript)
├─ UIButtonUtils (existing ModuleScript; updated source)
└─ UIAudioConfig (existing ModuleScript; updated source)
```

Required authored objects (already named in the feature specification):

```text
Workspace > SpinWheel > TriggerPart (BasePart)
StarterGui > LuckySpinUI (ScreenGui) > MainFrame
├─ FhiaTokenIndicator
│  ├─ TokenCounter (TextLabel)
│  └─ Token (ImageButton) > FhiaTokenInfo (ImageLabel)
├─ Buttons
│  ├─ Spin (ImageButton)
│  ├─ Buyx1 (ImageButton)
│  └─ Buyx10 (ImageButton)
├─ SpinWheelDecoration > Wheel (GuiObject with Rotation)
├─ StateLabels
│  ├─ Failed (TextLabel)
│  └─ Success (TextLabel; RichText enabled)
└─ ExitButton (ImageButton; legacy Close, Exit, or CloseButton names are also supported)
```

Enable `RichText` on the Success label so rarity coloring renders. Ensure `ServerStorage > RobuxExclusiveCarTools` and `ServerStorage > RobuxExclusiveCarModels` contain the Raiju exclusive assets used by the existing ownership path. The configured Developer Products are `3709203413` (+1 token) and `3709203785` (+10 tokens).

Set `LuckySpinUI.ResetOnSpawn` to `false`; the single StarterPlayer controller then keeps its references and trigger connection across R6/R15 character respawns without producing duplicate UI connections.
