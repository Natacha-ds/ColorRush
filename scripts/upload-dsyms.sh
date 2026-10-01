#!/bin/sh
#
# Uploads dSYMs to Sentry so crash reports are symbolicated.
#
# Wire this up as a "Run Script" build phase on the ColorGame target, placed
# after "Embed Frameworks", with "Based on dependency analysis" unchecked and
# this input file declared:
#
#   ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${EXECUTABLE_NAME}
#
# The auth token is deliberately NOT stored here. sentry-cli reads it from
# .sentryclirc at the repository root, which is gitignored:
#
#   [auth]
#   token=sntrys_...
#
# A failed upload only warns: a broken token must never break the build.

set -u

if [ "${CONFIGURATION:-}" = "Debug" ]; then
  exit 0
fi

if [ "$(uname -m)" = "arm64" ]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi

if ! which sentry-cli >/dev/null 2>&1; then
  echo "warning: sentry-cli not installed, dSYMs were not uploaded (brew install getsentry/tools/sentry-cli)"
  exit 0
fi

export SENTRY_ORG=tonic-studio
export SENTRY_PROJECT=color-rush

ERROR=$(sentry-cli debug-files upload --include-sources "${DWARF_DSYM_FOLDER_PATH}" 2>&1 >/dev/null)
if [ $? -ne 0 ]; then
  echo "warning: sentry-cli - ${ERROR}"
fi
