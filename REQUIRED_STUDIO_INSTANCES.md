# Required Studio Instances

The code redemption implementation does **not** create communication objects at runtime. Create the following instance manually in Roblox Studio before enabling the scripts.

| Class | Name | Parent hierarchy | Purpose |
| --- | --- | --- | --- |
| `RemoteFunction` | `ShopCodeRedemptionFunction` | `ReplicatedStorage > ShopCodeRedemptionFunction` | Client-to-server request/response endpoint for Shop promo code redemption. |

The following scripts/modules are represented by repository source files and should be placed in their documented locations:

| Class | Name | Parent hierarchy |
| --- | --- | --- |
| `ModuleScript` | `PromoCodeConfig` | `ReplicatedStorage > PromoCodeConfig` |
| `Script` | `ShopCodeRedemptionService` | `ServerScriptService > ShopCodeRedemptionService` |
| `LocalScript` | `ShopClient` | `StarterGui > ShopUI > ShopClient` |

Existing dependencies that must already be present:

| Class | Name | Parent hierarchy |
| --- | --- | --- |
| `BindableFunction` | `TycoonAdminAPI` | `ServerStorage > TycoonAdminAPI` |
| `ModuleScript` | `UIButtonUtils` | `ReplicatedStorage > UIButtonUtils` |
| `ModuleScript` | `UIAudioConfig` | `ReplicatedStorage > UIAudioConfig` |
