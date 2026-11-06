set -euo pipefail

cd app
composer install --no-interaction --prefer-dist --no-progress

psalm=./vendor/bin/psalm
if [[ ! -x "$psalm" ]]; then
    tool_dir="$(mktemp -d)"
    composer --working-dir="$tool_dir" require --no-interaction --no-plugins --no-scripts --no-progress vimeo/psalm:7.0.4
    psalm="$tool_dir/vendor/bin/psalm"
fi
if [[ ! -f psalm.xml && ! -f psalm.xml.dist ]]; then
    "$psalm" --init app 4
fi

raw_sarif="$(mktemp --suffix=.sarif)"
trap 'rm -f "$raw_sarif"' EXIT
status=0
"$psalm" --output-format=github --no-progress --report="$raw_sarif" || status=$?
if [[ -s "$raw_sarif" ]]; then
    jq '
        walk(
            if type == "object" and (.artifactLocation.uri? | type) == "string" then
                .artifactLocation.uri |=
                    if test("^(/|[A-Za-z][A-Za-z0-9+.-]*:)") then . else "app/" + . end
            else
                .
            end
        )
    ' "$raw_sarif" > "$RUNNER_TEMP/psalm.sarif"
    echo 'sarif_ready=true' >> "$GITHUB_OUTPUT"
elif [[ "$status" -eq 0 ]]; then
    echo 'Psalm did not produce a SARIF report' >&2
    exit 1
fi
exit "$status"
