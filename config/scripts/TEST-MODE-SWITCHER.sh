#!/usr/bin/env bash
# Test script untuk verifikasi mode switcher works dengan BUKTI REAL

echo "======================================"
echo "MODE SWITCHER - MANUAL TEST"
echo "======================================"
echo ""
echo "Gua akan test desktop-mode dan verify SEMUA settings."
echo ""
echo "Press ENTER to continue..."
read

echo ""
echo "======================================"
echo "STEP 1: BEFORE STATE"
echo "======================================"
echo "Fingerprint:  $(systemctl is-enabled fprintd.service 2>&1 | head -1)"
echo "Touchpad:     $(gsettings get org.gnome.desktop.peripherals.touchpad send-events)"
echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo "Turbo:        $(cat /sys/devices/system/cpu/intel_pstate/no_turbo) (0=ON, 1=OFF)"
echo "CPU Cap:      $(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct)%"
echo "Platform:     $(cat /sys/firmware/acpi/platform_profile)"
echo "Battery:      $(cat /sys/class/power_supply/BAT0/charge_control_start_threshold)-$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold)%"
echo ""
echo "Press ENTER to run desktop-mode..."
read

echo ""
echo "======================================"
echo "STEP 2: RUN DESKTOP-MODE"
echo "======================================"
@HOME@/scripts/desktop-mode.sh

echo ""
echo "Press ENTER to verify MANUAL (bukti real)..."
read

echo ""
echo "======================================"
echo "STEP 3: MANUAL VERIFICATION (PROOF)"
echo "======================================"
echo ""
echo "Expected vs Actual:"
echo ""

FP=$(systemctl is-enabled fprintd.service 2>&1 | head -1 | tr -d '\n\r')
if [[ "$FP" == "masked" ]]; then
    echo "✅ Fingerprint: DISABLED (expected: masked, got: $FP)"
else
    echo "❌ Fingerprint: FAILED (expected: masked, got: $FP)"
fi

TP=$(gsettings get org.gnome.desktop.peripherals.touchpad send-events)
if [[ "$TP" == "'disabled'" ]]; then
    echo "✅ Touchpad: DISABLED (expected: 'disabled', got: $TP)"
else
    echo "❌ Touchpad: FAILED (expected: 'disabled', got: $TP)"
fi

GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [[ "$GOV" == "powersave" ]]; then
    echo "✅ CPU Governor: powersave (got: $GOV)"
else
    echo "⚠️  CPU Governor: $GOV (expected: powersave)"
fi

TURBO=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
if [[ "$TURBO" == "0" ]]; then
    echo "✅ Turbo: ENABLED (got: $TURBO)"
else
    echo "⚠️  Turbo: $TURBO (expected: 0)"
fi

CAP=$(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct)
if [[ "$CAP" == "90" ]]; then
    echo "✅ CPU Cap: 90% (got: $CAP%) *** CRITICAL TEST ***"
else
    echo "❌ CPU Cap: FAILED (expected: 90%, got: $CAP%) *** BROKEN BEFORE ***"
fi

PLAT=$(cat /sys/firmware/acpi/platform_profile)
if [[ "$PLAT" == "balanced" ]]; then
    echo "✅ Platform: balanced (got: $PLAT) *** CRITICAL TEST ***"
else
    echo "❌ Platform: FAILED (expected: balanced, got: $PLAT) *** BROKEN BEFORE ***"
fi

BAT_START=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold)
BAT_STOP=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold)
echo "ℹ️  Battery: $BAT_START-$BAT_STOP% (NOT managed by script, GNOME controls)"

echo ""
echo "======================================"
echo "RESULT SUMMARY"
echo "======================================"
echo ""
echo "If CPU Cap = 90% and Platform = balanced:"
echo "  🎉 SUCCESS! Script works perfectly!"
echo ""
echo "If CPU Cap != 90% or Platform != balanced:"
echo "  ❌ FAILED! Script still broken!"
echo ""
echo "Press ENTER to test laptop-mode (revert)..."
read

echo ""
echo "======================================"
echo "STEP 4: TEST LAPTOP-MODE (REVERT)"
echo "======================================"
@HOME@/scripts/laptop-mode.sh

echo ""
echo "Press ENTER for final verification..."
read

echo ""
echo "======================================"
echo "STEP 5: FINAL VERIFICATION"
echo "======================================"
echo ""
echo "After laptop-mode:"
echo "Fingerprint:  $(systemctl is-active fprintd.service 2>&1 | head -1)"
echo "Touchpad:     $(gsettings get org.gnome.desktop.peripherals.touchpad send-events)"
echo "CPU Cap:      $(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct)% (expected: 85%)"
echo "Platform:     $(cat /sys/firmware/acpi/platform_profile) (expected: low-power)"
echo "Battery:      $(cat /sys/class/power_supply/BAT0/charge_control_start_threshold)-$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold)%"
echo ""
echo "======================================"
echo "TEST COMPLETE"
echo "======================================"
echo ""
echo "Check if all values match expected!"
echo ""
