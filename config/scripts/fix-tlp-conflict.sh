#!/usr/bin/env bash
# Fix TLP conflict with mode scripts
# Run this ONCE to disable TLP service

echo "======================================"
echo "FIX TLP CONFLICT"
echo "======================================"
echo ""
echo "Problem: TLP auto-override platform profile"
echo "Solution: Disable TLP service completely"
echo ""
echo "Mode scripts will handle everything:"
echo "  ✅ Platform profile"
echo "  ✅ WiFi power save"
echo "  ✅ USB autosuspend"
echo ""
echo "Press ENTER to continue or Ctrl+C to cancel..."
read

echo ""
echo "Stopping TLP service..."
sudo systemctl stop tlp.service

echo "Disabling TLP service (won't start on boot)..."
sudo systemctl disable tlp.service

echo ""
echo "✓ TLP disabled!"
echo ""

echo "Testing platform change (should work now)..."
echo "Current platform:"
cat /sys/firmware/acpi/platform_profile

echo ""
echo "Setting to balanced..."
echo balanced | sudo tee /sys/firmware/acpi/platform_profile >/dev/null
sleep 1

echo "Checking result:"
PLATFORM=$(cat /sys/firmware/acpi/platform_profile)
echo "$PLATFORM"

if [[ "$PLATFORM" == "balanced" ]]; then
    echo ""
    echo "✅ SUCCESS! Platform change works!"
    echo "   TLP no longer override!"
    echo ""
    echo "Now test laptop-mode script:"
    echo "  ~/scripts/laptop-mode.sh"
    echo ""
    echo "Platform should be 'balanced' after running it!"
else
    echo ""
    echo "⚠️  Still not working. Check manually."
fi

echo ""
echo "To re-enable TLP later:"
echo "  sudo systemctl enable tlp.service"
echo "  sudo systemctl start tlp.service"
echo ""
