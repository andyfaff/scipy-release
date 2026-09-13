set -euo pipefail
shopt -s nullglob
reference_wheels=(reference/*.whl)
rebuilt_wheels=(rebuilt/*.whl)

if (( ${#reference_wheels[@]} != 1 )); then
    echo "Expected exactly one reference wheel, found ${#reference_wheels[@]}" >&2
    exit 2
fi
if (( ${#rebuilt_wheels[@]} != 1 )); then
    echo "Expected exactly one rebuilt wheel, found ${#rebuilt_wheels[@]}" >&2
    exit 2
fi

{
    echo "## $1 reproducibility"
    echo '```'
    sha256sum "${reference_wheels[0]}" "${rebuilt_wheels[0]}"
    echo '```'
} | tee -a "$GITHUB_STEP_SUMMARY"

set +e
diffoscope \
    --text diffoscope.txt \
    --html diffoscope.html \
    "${reference_wheels[0]}" "${rebuilt_wheels[0]}"
status=$?
set -e

if (( status != 0 )) && [[ -f diffoscope.txt ]]; then
    # The complete reports are uploaded separately; keep the log manageable.
    sed -n '1,1000p' diffoscope.txt
fi
exit "$status"
