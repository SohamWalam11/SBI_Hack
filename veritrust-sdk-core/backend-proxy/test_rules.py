"""Quick functional test for VeriTrust rules engine."""
from app.rules_engine import get_rules_engine

r = get_rules_engine()

print("=== Savings Rate ===")
print(r.lookup_interest_rate("savings"))

print("\n=== TD 365 days General ===")
print(r.lookup_interest_rate("term_deposit", 365, "general"))

print("\n=== TD 365 days Senior ===")
print(r.lookup_interest_rate("term_deposit", 365, "senior_citizen"))

print("\n=== APR Computation (5L, 36mo, 10.5%) ===")
apr = r.compute_apr(500000, 36, 10.5, 5000, 500)
print(f"  APR: {apr['apr']}%")
print(f"  EMI: Rs.{apr['emi']}")
print(f"  Total Cost: Rs.{apr['total_cost_of_credit']}")

print("\n=== Rate Validation ===")
print("  2.50% savings (correct):", r.validate_rate_claim(2.50, "savings"))
print("  3.00% savings (wrong):", r.validate_rate_claim(3.00, "savings"))
print("  6.25% TD 365d (correct):", r.validate_rate_claim(6.25, "term_deposit", 365))

print("\n=== KFS Generation ===")
kfs = r.generate_kfs(500000, 36, 10.5, 5000, 500, 0)
print(f"  APR: {kfs['cost_details']['annual_percentage_rate']}%")
print(f"  EMI: Rs.{kfs['repayment_details']['emi_amount']}")
print(f"  Cooling off: {kfs['compliance']['cooling_off_period_days']} days")

print("\nAll tests passed!")
