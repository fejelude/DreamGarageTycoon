# Player data persistence deployment checklist

`ServerScriptService.TycoonDataHandler` is the sole owner of the main player
profile. Deploy exactly one enabled copy. It currently uses:

- DataStore: `DreamGarageTycoon_PlayerProfiles_Production_V1`
- Profile key: `User_V27_<Player.UserId>`

Do not rename either value for an existing production experience. A different
name or prefix is a separate, apparently empty datastore; it does not migrate
the old records automatically.

## Required Studio setup

1. Publish the place to the same experience/universe that owns the production
   data. DataStores are scoped to an experience.
2. In **Game Settings > Security**, enable **Studio Access to API Services**
   only when testing against data you are prepared to modify. Prefer a separate
   test experience for destructive testing.
3. Put the current `TycoonDataHandler` in `ServerScriptService`, leave it
   enabled, and remove/disable older duplicate copies.
4. Keep its required shared modules in `ReplicatedStorage`: `CarStats`,
   `BaseSkinStats`, `BaseAppearanceConfig`, `IndexConfig`, `RankConfig`, and
   the other dependencies reported by the server Output if startup fails.
5. Keep the shop and rank persistence BindableFunctions in `ServerStorage`.
   Missing subsystem bindables are preserved on save rather than overwritten,
   but the affected subsystem cannot load or progress normally.

## Verification attributes and Output

During a server test, inspect the Player instance:

- `DataLoadState` must become `Ready`.
- `TycoonDataLoaded` must become `true`.
- `DataStoreName` and `DataProfileKey` must match the values above.
- `LoadedDataLastUpdatedAt` reports the timestamp read on join.
- `LastSuccessfulDataSaveAt` changes after a successful save.
- `DataSaveError` is absent after success and contains the last datastore error
  after a failed attempt.

The server prints `Saving data for <name>...` and, for a final save,
`Saved: <name>`. A `Save Failed` line is actionable and must not be ignored.

## Join / modify / leave / rejoin test

Use a published server with API access and one test account. Record the Wallet,
one inventory car, a setting, and rank progress. Change all four, leave normally,
and wait for the server Output to confirm the final save. Rejoin the same
experience and account, confirm `DataLoadState == Ready`, and compare all four
values. Repeat once with **Start Server / Start Player** to exercise shutdown.

Do not use **Run** as a persistence test: it does not reproduce a normal player
join/leave lifecycle. Different Studio test players also have different user IDs
and therefore different profile keys.

## Legacy Bank migration

Migration version 1 atomically adds the sanitized stored `Bank` and
`ATMBalance` values to `Wallet` during profile lease acquisition, zeros the
legacy fields, and stores `WalletEconomyMigrationVersion = 1` in the same
`UpdateAsync`. It cannot run twice for the same successfully updated profile.
Do not manually remove or edit these legacy keys before every production player
has joined at least once on the migrated server.
