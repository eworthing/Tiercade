#!/usr/bin/env zsh
# tools/tvOS_smoketest.sh
# Safe tvOS smoke-test launcher.
# Writes a full trace to /tmp/tiercade_smoketest.log and does not exit on first failure.

LOG=/tmp/tiercade_smoketest.log
UDID=${1:-08740B5F-A5BF-4E06-AF6E-AEA889E21999}
APP_BUNDLE_ID=${2:-eworthing.Tiercade}

echo "Smoke-test started: $(date)" > $LOG
echo "SCRIPT: $0" >> $LOG
echo "UDID: $UDID" >> $LOG
echo "APP_BUNDLE_ID: $APP_BUNDLE_ID" >> $LOG
echo "PATH: $PATH" >> $LOG

echo "--- xcrun --version ---" >> $LOG
xcrun --version >> $LOG 2>&1 || echo "xcrun missing or failed" >> $LOG

echo "--- simctl list devices (short) ---" >> $LOG
xcrun simctl list devices >> $LOG 2>&1 || echo "simctl list failed" >> $LOG

echo "--- bootstatus for $UDID ---" >> $LOG
xcrun simctl bootstatus $UDID -b >> $LOG 2>&1 || echo "bootstatus returned nonzero" >> $LOG

echo "--- screenshot baseline ---" >> $LOG
xcrun simctl io $UDID screenshot /tmp/tiercade_before.png >> $LOG 2>&1 || echo "screenshot baseline failed" >> $LOG
ls -lh /tmp/tiercade_before.png >> $LOG 2>&1 || true

echo "--- UI presses (safe) ---" >> $LOG
for btn in Menu Right Right Select Down Select; do
  echo "press $btn" >> $LOG
  xcrun simctl ui $UDID press $btn >> $LOG 2>&1 || echo "press $btn failed" >> $LOG
  sleep 0.3
done

echo "--- screenshot after ---" >> $LOG
xcrun simctl io $UDID screenshot /tmp/tiercade_after.png >> $LOG 2>&1 || echo "screenshot after failed" >> $LOG
ls -lh /tmp/tiercade_after.png >> $LOG 2>&1 || true

echo "--- find app data container and copy debug log ---" >> $LOG
APP_DATA=$(xcrun simctl get_app_container $UDID $APP_BUNDLE_ID data 2>/dev/null) || APP_DATA=""
echo "APP_DATA=$APP_DATA" >> $LOG
if [ -n "$APP_DATA" ] && [ -f "$APP_DATA/Documents/tiercade_debug.log" ]; then
  cp "$APP_DATA/Documents/tiercade_debug.log" /tmp/tiercade_debug_log_from_container.txt >> $LOG 2>&1 || true
  echo "copied debug log to /tmp/tiercade_debug_log_from_container.txt" >> $LOG
else
  echo "no tiercade debug log found in app container" >> $LOG
fi

echo "--- tail of copied debug log (if present) ---" >> $LOG
tail -n 200 /tmp/tiercade_debug_log_from_container.txt >> $LOG 2>&1 || true

echo "--- summarize artifacts ---" >> $LOG
ls -lh /tmp/tiercade_*.png /tmp/tiercade_debug_log_from_container.txt /tmp/tiercade_smoketest.log >> $LOG 2>&1 || true

echo "Smoke-test finished: $(date)" >> $LOG

echo "Finished. Full log: $LOG"

echo "Artifacts:"
ls -lh /tmp/tiercade_*.png /tmp/tiercade_debug_log_from_container.txt /tmp/tiercade_smoketest.log || true

echo "You can view the log: /tmp/tiercade_smoketest.log"
