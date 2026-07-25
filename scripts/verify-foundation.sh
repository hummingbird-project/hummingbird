#!/bin/bash
# Verify package with no trait does not require libFoundation.so or libFoundationInternationalization.so
# This script only checks the dynamic libs referenced by the PerformanceTest executable.

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }


PRODUCT=$1
TRAITS=${2:-}

echo "Build $PRODUCT"
if [ -z "$TRAITS" ]; then
    swift build -c release --disable-default-traits --product "$PRODUCT"
else
    swift build -c release --traits "$TRAITS" --product "$PRODUCT"
fi

BINPATH=$(swift build -c release --show-bin-path)
echo "$PRODUCT can be found in $BINPATH"
OBJDUMP=$(objdump -p "$BINPATH"/"$PRODUCT" | grep "NEEDED")

LIBS_TO_CHECK="libFoundation.so libFoundationInternationalization.so lib_FoundationICU.so"
for LIB in ${LIBS_TO_CHECK}; do
  echo -n "Checking for ${LIB}... "
  
  # check if the binary has a dependency on Foundation or ICU
  echo "${OBJDUMP}" | grep "${LIB}"  # return 1 if not found

  # 1 is success (grep failed to find the lib), 0 is failure (grep successly found the lib)
  SUCCESS=$?
  if [ "$SUCCESS" -eq 0 ]; then
    log "❌ ${LIB} found." && break
  else
    log "✅ ${LIB} not found."
  fi
done

# exit code is the opposite of the grep exit code
if [ "$SUCCESS" -eq 0 ]; then
  fatal "❌ At least one foundation lib was found, reporting the error."
else
  log "✅ No foundation lib found, congrats!" && exit 0
fi