"""Regression checks for the main Roblox profile lifecycle.

These tests cannot call Roblox DataStoreService, but they exercise the migration
contract with representative profiles and pin the save/load fields and shutdown
ordering that previously made failed final saves unrecoverable.
"""
from copy import deepcopy
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
HANDLER = (ROOT / "TycoonDataHandler").read_text()


def migrate(profile: dict) -> dict:
    """Python model of WALLET_ECONOMY_MIGRATION_VERSION 1."""
    result = deepcopy(profile)
    if int(result.get("WalletEconomyMigrationVersion") or 0) < 1:
        def money(value):
            try:
                return max(0, int(float(value or 0)))
            except (TypeError, ValueError, OverflowError):
                return 0
        result["Wallet"] = money(result.get("Wallet")) + money(result.get("Bank")) + money(result.get("ATMBalance"))
        result["Bank"] = 0
        result["ATMBalance"] = 0
        result.pop("BankTransferLimitUsed", None)
        result.pop("BankTransferLimitResetAt", None)
        result["WalletEconomyMigrationVersion"] = 1
    return result


class PersistenceLifecycleTests(unittest.TestCase):
    def test_legacy_money_migrates_once(self):
        original = {"Wallet": 25, "Bank": 50, "ATMBalance": 75}
        once = migrate(original)
        twice = migrate(once)
        self.assertEqual(once["Wallet"], 150)
        self.assertEqual(twice, once)

    def test_migration_preserves_unrelated_profile_state(self):
        original = {
            "Wallet": 10, "Bank": 20, "ATMBalance": 30,
            "Inventory": ["Delta Item"], "Layout": [{"Tool": "Delta Item", "Pad": "Pad1"}],
            "Settings": {"MusicEnabled": False},
            "Tutorial": {"Stage": "Part4"},
            "RankData": {"CurrentRank": "VIP"},
            "IndexDiscovered": ["Delta"],
        }
        migrated = migrate(original)
        for field in ("Inventory", "Layout", "Settings", "Tutorial", "RankData", "IndexDiscovered"):
            self.assertEqual(migrated[field], original[field])

    def test_main_save_contains_multiple_persistent_domains(self):
        for assignment in (
            "oldData.Wallet     = snapshotWallet",
            "oldData.Inventory = finalInventory",
            "oldData.Layout = finalLayout",
            "oldData.Settings = currentSettings",
            "oldData.Tutorial = currentTutorial",
            "oldData.RankData = currentRankData",
            "oldData.IndexDiscovered = currentIndexDiscovered",
        ):
            self.assertIn(assignment, HANDLER)

    def test_final_save_retries_before_subsystem_cleanup(self):
        retry = HANDLER.index("for attempt = 1, FINAL_SAVE_ATTEMPTS do")
        cleanup = HANDLER.index("closePersistenceSessions(player)", retry)
        release = HANDLER.index("releaseProfileLeaseWithoutSave(session)", cleanup)
        self.assertLess(retry, cleanup)
        self.assertLess(cleanup, release)

    def test_load_and_save_diagnostics_are_present(self):
        for attribute in (
            'DataLoadState", "Ready', "LoadedDataLastUpdatedAt",
            "LastSuccessfulDataSaveAt", "DataSaveError", "DataStoreName", "DataProfileKey",
        ):
            self.assertIn(attribute, HANDLER)


if __name__ == "__main__":
    unittest.main()
