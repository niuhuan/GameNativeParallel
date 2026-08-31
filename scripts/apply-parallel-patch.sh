#!/usr/bin/env bash
set -euo pipefail

source_root="${1:-$PWD}"
application_id="${PARALLEL_APPLICATION_ID:-app.gamenative.parallel}"
application_name="${PARALLEL_APP_NAME:-GameNative Parallel}"

fail() {
    echo "Parallel patch error: $*" >&2
    exit 1
}

replace_exact() {
    local file="$1"
    local from="$2"
    local to="$3"
    local expected_count="$4"

    [[ -f "$file" ]] || fail "missing required file: $file"

    python3 - "$file" "$from" "$to" "$expected_count" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
old, new = sys.argv[2], sys.argv[3]
expected = int(sys.argv[4])
contents = path.read_text(encoding="utf-8")
count = contents.count(old)
if count != expected:
    raise SystemExit(
        f"Parallel patch error: expected {expected} occurrence(s) of {old!r} "
        f"in {path}, found {count}"
    )
path.write_text(contents.replace(old, new), encoding="utf-8")
PY
}

[[ -d "$source_root/app" ]] || fail "not a GameNative source tree: $source_root"

replace_exact \
    "$source_root/app/build.gradle.kts" \
    'applicationId = "app.gamenative"' \
    "applicationId = \"$application_id\"" \
    1

mapfile -t string_files < <(
    find "$source_root/app/src/main/res" -type f -path '*/values*/strings.xml' -print | sort
)
(( ${#string_files[@]} > 0 )) || fail "no Android string resources found"

for strings_file in "${string_files[@]}"; do
    replace_exact \
        "$strings_file" \
        '<string name="app_name">GameNative</string>' \
        "<string name=\"app_name\">$application_name</string>" \
        1
    replace_exact \
        "$strings_file" \
        '<string name="login_app_name">GameNative</string>' \
        "<string name=\"login_app_name\">$application_name</string>" \
        1
done

replace_exact \
    "$source_root/app/src/main/AndroidManifest.xml" \
    'android:name="app.gamenative.LAUNCH_GAME"' \
    "android:name=\"$application_id.LAUNCH_GAME\"" \
    1
replace_exact \
    "$source_root/app/src/main/AndroidManifest.xml" \
    'android:scheme="app.gamenative"' \
    "android:scheme=\"$application_id\"" \
    1
replace_exact \
    "$source_root/app/src/main/java/app/gamenative/mods/NexusOAuthModels.kt" \
    'const val REDIRECT_URI = "app.gamenative://oauth/callback"' \
    "const val REDIRECT_URI = \"$application_id://oauth/callback\"" \
    1
replace_exact \
    "$source_root/app/src/main/java/app/gamenative/utils/IntentLaunchManager.kt" \
    'private const val ACTION_LAUNCH_GAME = "app.gamenative.LAUNCH_GAME"' \
    "private const val ACTION_LAUNCH_GAME = \"$application_id.LAUNCH_GAME\"" \
    1
replace_exact \
    "$source_root/app/src/main/java/app/gamenative/utils/ShortcutUtils.kt" \
    'val intent = Intent("app.gamenative.LAUNCH_GAME").apply {' \
    "val intent = Intent(\"$application_id.LAUNCH_GAME\").apply {" \
    1
replace_exact \
    "$source_root/app/src/main/java/app/gamenative/ui/components/BootingSplash.kt" \
    'text = "GameNative",' \
    "text = \"$application_name\"," \
    2

echo "Applied Parallel identity patch to $source_root"
